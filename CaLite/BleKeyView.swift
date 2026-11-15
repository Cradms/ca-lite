import SwiftUI
import CoreBluetooth

// MARK: - 认证 / 帧编解码边界（对应源码 BleKeyClient.AuthProvider）

struct BleKeyMaterial {
    var mac = ""
    var keyId = ""
    var token = ""
    var vin = ""
    var userId = ""
    var tuId = ""
    var type = ""
    var secret: Data?
    var scanName = ""
}

protocol BleAuthProvider {
    /// 收到车端 challenge 后生成认证帧；nil 表示无需握手
    func buildAuthFrame(key: BleKeyMaterial, challenge: Data) -> Data?
    /// 校验车端认证应答
    func verifyAuthResponse(key: BleKeyMaterial, frame: Data) -> Bool
    /// 指令帧封装
    func sealCommand(key: BleKeyMaterial, cmdCode: String, payload: Data?) -> Data
    /// 车况帧解封装；nil 表示握手/ACK 帧
    func unsealVehicleState(key: BleKeyMaterial, frame: Data) -> Data?
}

/// 与源码 PlainAuthProvider 一致：不握手、不加密、TLV 直传。
/// 源码注释：原 APK 的握手与加密在加固 dex 内（未静态还原），这里只做联调。
struct PlainAuthProvider: BleAuthProvider {
    func buildAuthFrame(key: BleKeyMaterial, challenge: Data) -> Data? { nil }
    func verifyAuthResponse(key: BleKeyMaterial, frame: Data) -> Bool { true }
    func sealCommand(key: BleKeyMaterial, cmdCode: String, payload: Data?) -> Data {
        var d = Data(cmdCode.utf8)
        if let p = payload { d.append(p) }
        return d
    }
    func unsealVehicleState(key: BleKeyMaterial, frame: Data) -> Data? { frame }
}

/// 源码 Cmd 常量（0101 锁车 … 010D 关天窗）
struct BleCmdItem: Identifiable {
    let id = UUID()
    let title: String
    let code: String
}

enum BleCmd {
    static let lockDoor     = "0101"
    static let unlockDoor   = "0102"
    static let openWindow   = "0103"
    static let closeWindow  = "0104"
    static let openTrunk    = "0105"
    static let closeTrunk   = "0106"
    static let startEngine  = "0107"
    static let stopEngine   = "0108"
    static let whistle      = "010B"
    static let openSunroof  = "010C"
    static let closeSunroof = "010D"

    static let all: [BleCmdItem] = [
        BleCmdItem(title: "锁车", code: lockDoor),
        BleCmdItem(title: "解锁", code: unlockDoor),
        BleCmdItem(title: "开窗", code: openWindow),
        BleCmdItem(title: "关窗", code: closeWindow),
        BleCmdItem(title: "开后备箱", code: openTrunk),
        BleCmdItem(title: "关后备箱", code: closeTrunk),
        BleCmdItem(title: "启动", code: startEngine),
        BleCmdItem(title: "熄火", code: stopEngine),
        BleCmdItem(title: "鸣笛", code: whistle),
        BleCmdItem(title: "开天窗", code: openSunroof),
        BleCmdItem(title: "关天窗", code: closeSunroof)
    ]
}

// MARK: - BLE 管理器

final class BleManager: NSObject, ObservableObject {

    struct Device: Identifiable {
        let id: UUID
        let name: String
        let rssi: Int
        let adv: String
        let peripheral: CBPeripheral
    }

    struct CharInfo: Identifiable {
        let id: String
        let service: String
        let uuid: String
        let props: String
        let characteristic: CBCharacteristic
    }

    @Published var stateText = "未开始"
    @Published var devices: [Device] = []
    @Published var chars: [CharInfo] = []
    @Published var logs: [String] = []
    @Published var connectedName = ""

    private var central: CBCentralManager!
    private var target: CBPeripheral?
    private var writeChar: CBCharacteristic?
    private var notifyChar: CBCharacteristic?

    /// 可配置 UUID（源码默认 FFF0/FFF1/FFF2 是占位）
    var serviceUUID: String {
        get { Prefs.s("ble_service", "FFF0") }
        set { Prefs.set(newValue, "ble_service") }
    }
    var writeUUID: String {
        get { Prefs.s("ble_write", "FFF1") }
        set { Prefs.set(newValue, "ble_write") }
    }
    var notifyUUID: String {
        get { Prefs.s("ble_notify", "FFF2") }
        set { Prefs.set(newValue, "ble_notify") }
    }

    override init() {
        super.init()
        central = CBCentralManager(delegate: self, queue: nil)
    }

    func startScan() {
        guard central.state == .poweredOn else {
            stateText = "蓝牙不可用：\(stateName(central.state))"
            return
        }
        devices.removeAll()
        chars.removeAll()
        stateText = "扫描中…"
        central.scanForPeripherals(withServices: nil,
                                   options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
    }

    func stopScan() {
        central.stopScan()
        stateText = "已停止扫描"
    }

    func connect(_ d: Device) {
        stopScan()
        target = d.peripheral
        d.peripheral.delegate = self
        connectedName = d.name
        stateText = "连接 \(d.name)…"
        central.connect(d.peripheral, options: nil)
    }

    func disconnect() {
        if let p = target { central.cancelPeripheralConnection(p) }
        target = nil
        writeChar = nil
        notifyChar = nil
        chars.removeAll()
        connectedName = ""
        stateText = "已断开"
    }

    /// 按源码链路发一条指令：sealCommand → 写 write 特征
    func send(cmdCode: String, provider: BleAuthProvider = PlainAuthProvider()) {
        guard let ch = writeChar, let p = target else {
            log("没有可写特征，先连接")
            return
        }
        let frame = provider.sealCommand(key: BleKeyMaterial(), cmdCode: cmdCode, payload: nil)
        let type: CBCharacteristicWriteType =
            ch.properties.contains(.write) ? .withResponse : .withoutResponse
        p.writeValue(frame, for: ch, type: type)
        log("→ \(hex(frame))  (\(cmdCode))")
    }

    func sendHex(_ text: String) {
        guard let ch = writeChar, let p = target else {
            log("没有可写特征，先连接")
            return
        }
        guard let data = Self.parseHex(text), !data.isEmpty else {
            log("hex 格式不对")
            return
        }
        let type: CBCharacteristicWriteType =
            ch.properties.contains(.write) ? .withResponse : .withoutResponse
        p.writeValue(data, for: ch, type: type)
        log("→ \(hex(data))")
    }

    // MARK: 工具

    static func parseHex(_ s: String) -> Data? {
        let clean = s.replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "0x", with: "")
            .replacingOccurrences(of: ",", with: "")
        guard clean.count % 2 == 0 else { return nil }
        var d = Data()
        var i = clean.startIndex
        while i < clean.endIndex {
            let next = clean.index(i, offsetBy: 2)
            guard let b = UInt8(clean[i..<next], radix: 16) else { return nil }
            d.append(b)
            i = next
        }
        return d
    }

    func hex(_ d: Data) -> String {
        d.map { String(format: "%02X", $0) }.joined(separator: " ")
    }

    private func log(_ s: String) {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        let line = "[\(f.string(from: Date()))] \(s)"
        DispatchQueue.main.async {
            self.logs.insert(line, at: 0)
            if self.logs.count > 200 { self.logs.removeLast(self.logs.count - 200) }
        }
    }

    private func stateName(_ s: CBManagerState) -> String {
        switch s {
        case .poweredOff: return "系统蓝牙未打开"
        case .unauthorized: return "未授权蓝牙权限"
        case .unsupported: return "设备不支持 BLE"
        case .resetting: return "蓝牙重启中"
        case .unknown: return "状态未知"
        default: return "就绪"
        }
    }
}

extension BleManager: CBCentralManagerDelegate {

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        stateText = central.state == .poweredOn ? "蓝牙就绪，点扫描" : stateName(central.state)
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any], rssi RSSI: NSNumber) {
        let name = peripheral.name
            ?? (advertisementData[CBAdvertisementDataLocalNameKey] as? String)
            ?? "未命名"
        let adv = "\(advertisementData)"
        let dev = Device(id: peripheral.identifier, name: name,
                         rssi: RSSI.intValue, adv: adv, peripheral: peripheral)
        DispatchQueue.main.async {
            if let i = self.devices.firstIndex(where: { $0.id == dev.id }) {
                self.devices[i] = dev
            } else {
                self.devices.append(dev)
            }
            self.devices.sort { $0.rssi > $1.rssi }
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        stateText = "已连接 \(peripheral.name ?? "")，枚举服务…"
        log("已连接 \(peripheral.name ?? "")")
        peripheral.discoverServices(nil)
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral,
                        error: Error?) {
        stateText = "连接失败：\(error?.localizedDescription ?? "未知")"
        log("连接失败 \(error?.localizedDescription ?? "")")
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral,
                        error: Error?) {
        stateText = "连接已断开"
        log("断开 \(error?.localizedDescription ?? "")")
    }
}

extension BleManager: CBPeripheralDelegate {

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }
        for s in services {
            peripheral.discoverCharacteristics(nil, for: s)
        }
        log("服务 \(services.count) 个")
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let list = service.characteristics else { return }
        for c in list {
            var props: [String] = []
            if c.properties.contains(.read) { props.append("read") }
            if c.properties.contains(.write) { props.append("write") }
            if c.properties.contains(.writeWithoutResponse) { props.append("writeNR") }
            if c.properties.contains(.notify) { props.append("notify") }
            if c.properties.contains(.indicate) { props.append("indicate") }
            let info = CharInfo(id: service.uuid.uuidString + "/" + c.uuid.uuidString,
                                service: service.uuid.uuidString,
                                uuid: c.uuid.uuidString, props: props.joined(separator: "/"),
                                characteristic: c)
            DispatchQueue.main.async {
                if !self.chars.contains(where: { $0.id == info.id }) { self.chars.append(info) }
            }
            if c.properties.contains(.notify) || c.properties.contains(.indicate) {
                peripheral.setNotifyValue(true, for: c)
                if notifyChar == nil { notifyChar = c }
            }
            if c.properties.contains(.write) || c.properties.contains(.writeWithoutResponse) {
                if writeChar == nil { writeChar = c }
            }
        }
        log("特征 \(service.uuid.uuidString.prefix(8))… +\(list.count)")
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic,
                    error: Error?) {
        guard let d = characteristic.value else { return }
        log("← \(hex(d))")
    }

    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic,
                    error: Error?) {
        if let e = error { log("写入失败：\(e.localizedDescription)") }
    }
}

// MARK: - 调试页

struct BleKeyView: View {
    @StateObject private var ble = BleManager()
    @State private var hexInput = "0102"
    @State private var showUUIDSheet = false

    var body: some View {
        List {
            Section {
                HStack {
                    Circle()
                        .fill(ble.connectedName.isEmpty ? C.faint : C.green)
                        .frame(width: 8, height: 8)
                    Text(ble.stateText).font(.system(size: 12.5))
                    Spacer()
                }
                if ble.connectedName.isEmpty {
                    Button("扫描周边设备") { ble.startScan() }
                    Button("停止扫描") { ble.stopScan() }
                } else {
                    Button("断开连接", role: .destructive) { ble.disconnect() }
                }
                Button("配置 UUID（源码占位 FFF0/FFF1/FFF2）") { showUUIDSheet = true }
            } header: {
                Text("连接")
            }

            if !ble.devices.isEmpty {
                Section {
                    ForEach(ble.devices) { d in
                        Button {
                            ble.connect(d)
                        } label: {
                            VStack(alignment: .leading, spacing: 3) {
                                HStack {
                                    Text(d.name)
                                        .font(.system(size: 13.5, weight: .medium))
                                        .foregroundColor(C.txt)
                                    Spacer()
                                    Text("\(d.rssi) dBm")
                                        .font(.system(size: 11))
                                        .foregroundColor(d.rssi > -70 ? C.green : C.muted)
                                }
                                Text(d.adv)
                                    .font(.system(size: 9, design: .monospaced))
                                    .foregroundColor(C.faint)
                                    .lineLimit(2)
                            }
                        }
                    }
                } header: {
                    Text("周边设备（\(ble.devices.count)）")
                }
            }

            if !ble.chars.isEmpty {
                Section {
                    ForEach(ble.chars) { c in
                        VStack(alignment: .leading, spacing: 3) {
                            HStack {
                                Text(c.uuid)
                                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                                    .foregroundColor(C.txt)
                                Spacer()
                                Text(c.props)
                                    .font(.system(size: 9.5))
                                    .foregroundColor(C.blue)
                            }
                            Text("service \(c.service)")
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundColor(C.faint)
                        }
                    }
                } header: {
                    Text("特征（\(ble.chars.count)）")
                }

                Section {
                    HStack {
                        TextField("hex，如 0102", text: $hexInput)
                            .font(.system(size: 13, design: .monospaced))
                            .autocapitalization(.allCharacters)
                        Button("发送") { ble.sendHex(hexInput) }
                            .font(.system(size: 13, weight: .semibold))
                    }
                    VStack(spacing: 6) {
                        ForEach(Array(stride(from: 0, to: BleCmd.all.count, by: 2)), id: \.self) { i in
                            HStack(spacing: 6) {
                                cmdBtn(BleCmd.all[i])
                                if i + 1 < BleCmd.all.count { cmdBtn(BleCmd.all[i + 1]) }
                            }
                        }
                    }
                } header: {
                    Text("发指令（源码 Cmd 常量，明文直传）")
                } footer: {
                    Text("源码的 AuthProvider 只给了 PlainAuthProvider（不握手、不加密），这里也是明文。真机要能开锁得先抓到车端握手帧。")
                        .font(.system(size: 10))
                }
            }

            if !ble.logs.isEmpty {
                Section {
                    ForEach(Array(ble.logs.prefix(40).enumerated()), id: \.offset) { _, line in
                        Text(line)
                            .font(.system(size: 10.5, design: .monospaced))
                            .foregroundColor(C.muted)
                    }
                } header: {
                    Text("收发日志")
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("蓝牙钥匙 / BLE 调试")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showUUIDSheet) { uuidSheet }
    }

    private func cmdBtn(_ item: BleCmdItem) -> some View {
        Button {
            ble.send(cmdCode: item.code)
        } label: {
            Text("\(item.title) \(item.code)")
                .font(.system(size: 11))
                .foregroundColor(C.blue)
                .frame(maxWidth: .infinity)
                .frame(height: 30)
                .background(C.blue.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    private var uuidSheet: some View {
        NavigationView {
            Form {
                Section(header: Text("源码默认是占位值，按实车改")) {
                    TextField("Service  UUID", text: Binding(
                        get: { ble.serviceUUID },
                        set: { ble.serviceUUID = $0 }))
                    TextField("Write    UUID", text: Binding(
                        get: { ble.writeUUID },
                        set: { ble.writeUUID = $0 }))
                    TextField("Notify   UUID", text: Binding(
                        get: { ble.notifyUUID },
                        set: { ble.notifyUUID = $0 }))
                }
                Section {
                    Text("填 16 位短 UUID（如 FFF1）或完整 128 位。连上后在特征列表里能看到真实值，直接抄过来。")
                        .font(.system(size: 11.5))
                        .foregroundColor(C.muted)
                }
            }
            .navigationTitle("BLE UUID")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { showUUIDSheet = false }
                }
            }
        }
    }
}
