import SwiftUI

/// 首页
///
/// 版式按参考图：更新于 → 大号车牌 → 超大续航（右上角车模）→ 状态胶囊
/// → 胎压四轮 → 六宫格（解锁/留缝/天窗翘起/启动/空调/闪灯）
/// → 位置条 → 全部控制（源码 7 组 + 空调温度）→ footer
struct CarHomeView: View {
    @State private var st = CarState()
    @State private var loading = true
    @State private var showLogin = false
    @State private var showPinSheet = false
    @State private var pinInput = ""
    @State private var toast: String?
    @State private var alertMsg: String?
    @State private var sheet: HomeSheet?
    @State private var showAll = false
    @State private var showCars = false
    @State private var cars: [[String: Any]] = []
    @State private var airTemp = 24

    private let api = CarAPI.shared

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 12) {
                    heroCard
                    tyreCard
                    gridCard
                    locationBar
                    allControls
                    footer
                }
                .padding(.horizontal, 14)
                .padding(.top, 6)
                .padding(.bottom, 16)
            }
            .background(Color(hex: 0xEEF3F9).ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            pinInput = CarAPI.shared.controlPin
                            showPinSheet = true
                        } label: { Label("设置控车码", systemImage: "lock.shield") }
                        Button { loadCars() } label: {
                            Label("切换车辆", systemImage: "car.2.fill")
                        }
                        Button { sheet = .history } label: {
                            Label("操作记录", systemImage: "clock.arrow.circlepath")
                        }
                        Button { showLogin = true } label: {
                            Label("重新登录 / 扫码授权", systemImage: "person.badge.key")
                        }
                        Divider()
                        Button(role: .destructive) { logout() } label: {
                            Label("退出登录", systemImage: "rectangle.portrait.and.arrow.right")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle").foregroundColor(KH.blue)
                    }
                }
            }
        }
        .overlay(alignment: .bottom) {
            if let t = toast {
                Text(t)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 18).padding(.vertical, 10)
                    .background(Color(hex: 0x1A1E24).opacity(0.9))
                    .clipShape(Capsule())
                    .padding(.bottom, 28)
                    .transition(.opacity)
            }
        }
        .onAppear {
            airTemp = CarAPI.shared.cachedTemp > 0 ? CarAPI.shared.cachedTemp : 24
            if !api.isLoggedIn { showLogin = true } else { refresh() }
        }
        .sheet(isPresented: $showLogin) {
            LoginView {
                showLogin = false
                refresh()
            }
        }
        .sheet(isPresented: $showPinSheet) { pinSheet }
        .sheet(isPresented: $showCars) { carSheet }
        .sheet(item: $sheet) { s in
            switch s {
            case .location: NavigationView { LocationView() }
            case .track:    NavigationView { TrackView() }
            case .photo:    NavigationView { PhotoView() }
            case .more:     NavigationView { MoreView() }
            case .history:  NavigationView { HistoryView() }
            case .ble:      NavigationView { BleKeyView() }
            }
        }
        .alert(isPresented: Binding(get: { alertMsg != nil },
                                    set: { if !$0 { alertMsg = nil } })) {
            Alert(title: Text("提示"), message: Text(alertMsg ?? ""),
                  dismissButton: .default(Text("好")))
        }
    }

    // MARK: - 顶部信息区

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(timeLabel)
                .font(.system(size: 11.5))
                .foregroundColor(Color(hex: 0x6E7A8A))
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 6)

            HStack(alignment: .top, spacing: 6) {
                VStack(alignment: .leading, spacing: 8) {
                    Button { loadCars() } label: {
                        HStack(spacing: 6) {
                            Text(plateText)
                                .font(.system(size: 36, weight: .bold))
                                .foregroundColor(Color(hex: 0x1B3A6B))
                                .lineLimit(1)
                                .minimumScaleFactor(0.55)
                            Image(systemName: "chevron.down")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(Color(hex: 0x1B3A6B).opacity(0.45))
                        }
                    }
                    .buttonStyle(.plain)

                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("剩余续航：")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(Color(hex: 0x3B4B63))
                        Text(st.range.isEmpty ? "--" : st.range)
                            .font(.system(size: 44, weight: .bold))
                            .foregroundColor(Color(hex: 0x1B3A6B))
                        Text("km")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(Color(hex: 0x5A6B84))
                    }
                }
                Spacer(minLength: 0)
                Image(carImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 108)
                    .shadow(color: Color(hex: 0x1B3A6B).opacity(0.16), radius: 8, x: 0, y: 6)
                    .padding(.top, 18)
            }
            .padding(.top, 4)

            // 状态胶囊
            HStack(spacing: 8) {
                statusChip(st.engineOn ? "已启动" : "已熄火",
                           st.engineOn ? Color(hex: 0x2F9E68) : Color(hex: 0x6E7A8A))
                statusChip(st.lockFL ? "已锁车" : "未锁车",
                           st.lockFL ? Color(hex: 0x2F9E68) : Color(hex: 0xE53935))
                statusChip(st.sunOpen ? "天窗未关" : "天窗已关",
                           st.sunOpen ? Color(hex: 0xE53935) : Color(hex: 0x6E7A8A))
                statusChip(st.airOn ? "空调开" : "空调关",
                           st.airOn ? Color(hex: 0x2F6FB5) : Color(hex: 0x6E7A8A))
                Spacer(minLength: 0)
            }
            .padding(.top, 12)

            HStack(spacing: 8) {
                if !winText.isEmpty {
                    Text(winText)
                        .font(.system(size: 11.5))
                        .foregroundColor(Color(hex: 0xE53935))
                }
                if st.trunk {
                    Text("· 后备箱未关")
                        .font(.system(size: 11.5))
                        .foregroundColor(Color(hex: 0xE53935))
                }
            }
            .padding(.top, 6)
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            ZStack {
                LinearGradient(colors: [Color.white, Color(hex: 0xE8F0FA)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                Circle()
                    .fill(Color(hex: 0xBFD5EE).opacity(0.45))
                    .frame(width: 220, height: 220)
                    .blur(radius: 60)
                    .offset(x: 110, y: -90)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: Color(hex: 0x9DB4D0).opacity(0.25), radius: 12, x: 0, y: 6)
    }

    private func statusChip(_ text: String, _ color: Color) -> some View {
        Text(text)
            .font(.system(size: 10.5, weight: .medium))
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.10))
            .clipShape(Capsule())
    }

    private var plateText: String {
        st.carName.isEmpty ? "我的爱车" : st.carName
    }

    private var carImage: String {
        let code = CarModel.normalize(st.seriesName.isEmpty ? st.series : st.seriesName)
        return code.isEmpty ? "car" : "car_" + code.lowercased()
    }

    /// 车辆上报时间优先；拿不到才退回本机刷新时间（并在前缀上区分）
    private var isVehicleTime: Bool { !st.terminalRaw.isEmpty || st.vehicleTime > 0 }

    /// 车机时间优先（直接用 terminalTime 原文切，car-ios 就是这么显示的）
    private var timeText: String {
        if !st.terminalRaw.isEmpty {
            let p = CarAPI.prettyTerminal(st.terminalRaw)
            if !p.isEmpty { return p }
        }
        let stamp = st.vehicleTime > 0 ? st.vehicleTime : st.updatedAt
        return Stamp.text(Double(stamp), format: "MM.dd HH:mm")
    }

    private var timeLabel: String {
        isVehicleTime ? "车辆更新于 \(timeText)" : "本机刷新于 \(timeText)"
    }

    private var winText: String {
        var arr: [String] = []
        if st.winFL { arr.append("左前窗") }
        if st.winFR { arr.append("右前窗") }
        if st.winRL { arr.append("左后窗") }
        if st.winRR { arr.append("右后窗") }
        return arr.isEmpty ? "" : arr.joined(separator: "、") + "未关"
    }

    // MARK: - 胎压（源码 tireFl/tireFr/tireRl/tireRr）

    private var tyreCard: some View {
        HStack(spacing: 0) {
            tyre("左前", st.lf)
            dividerV
            tyre("右前", st.rf)
            dividerV
            tyre("左后", st.lr)
            dividerV
            tyre("右后", st.rr)
        }
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.9))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func tyre(_ pos: String, _ v: String) -> some View {
        let n = Double(v) ?? 0
        let warn = n > 0 && (n < 200 || n > 280)
        return VStack(spacing: 3) {
            Text(v.isEmpty ? "--" : v)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(warn ? Color(hex: 0xE53935) : Color(hex: 0x2B3A4F))
            Text("\(pos) kPa")
                .font(.system(size: 9.5))
                .foregroundColor(Color(hex: 0x8A94A3))
        }
        .frame(maxWidth: .infinity)
    }

    private var dividerV: some View {
        Rectangle()
            .fill(Color(hex: 0xE3EAF3))
            .frame(width: 1, height: 26)
    }

    // MARK: - 六宫格

    private var gridCard: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3),
                  spacing: 10) {
            tile("解锁", "lock.open", "UnLockDoor")
            tile("车窗留缝", "rectangle.split.3x1", "WindowSlit")
            tile("天窗翘起", "sun.max", "SkyWindowLiftUp")
            tile("启动发动机", "engine.combustion", "OpenEngine")
            tile("打开空调", "snowflake", "openAir")
            tile("闪灯", "lightbulb", "FlashLight")
        }
    }

    private func tile(_ title: String, _ icon: String, _ cmd: String) -> some View {
        Button {
            runCmd(cmd, title)
        } label: {
            VStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 26))
                    .foregroundColor(Color(hex: 0x1B3A6B))
                Text(title)
                    .font(.system(size: 13))
                    .foregroundColor(Color(hex: 0x2B3A4F))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 112)
            .background(Color.white.opacity(0.94))
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: Color(hex: 0xA8BCD4).opacity(0.22), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }

    // MARK: - 位置条

    private var locationBar: some View {
        Button { sheet = .location } label: {
            HStack(spacing: 8) {
                Image(systemName: "location.fill")
                    .font(.system(size: 12))
                    .foregroundColor(KH.blue)
                Text(st.addr.isEmpty ? "车辆位置：暂无位置（点此刷新）" : "车辆位置：\(st.addr)")
                    .font(.system(size: 12.5))
                    .foregroundColor(Color(hex: 0x2B3A4F))
                    .lineLimit(1)
                Spacer(minLength: 4)
                Image(systemName: "chevron.right")
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: 0xA9B3BE))
            }
            .padding(.horizontal, 14)
            .frame(height: 44)
            .background(Color.white.opacity(0.9))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: - 全部控制

    private var allControls: some View {
        VStack(spacing: 10) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { showAll.toggle() }
            } label: {
                HStack {
                    Text("全部控制")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color(hex: 0x2B3A4F))
                    Spacer()
                    Image(systemName: showAll ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11))
                        .foregroundColor(Color(hex: 0x8A94A3))
                }
                .padding(.horizontal, 14)
                .frame(height: 42)
                .background(Color.white.opacity(0.9))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)

            if showAll {
                // 工具入口
                HStack(spacing: 8) {
                    toolBtn("全景照片", "photo.on.rectangle") { sheet = .photo }
                    toolBtn("行车轨迹", "point.topleft.down.to.point.bottomright.curvepath") { sheet = .track }
                    toolBtn("操作记录", "clock.arrow.circlepath") { sheet = .history }
                    toolBtn("蓝牙钥匙", "key.fill") { sheet = .ble }
                }

                // 空调温度（源码 setTemperature：16–32）
                HStack(spacing: 10) {
                    Image(systemName: "thermometer.medium")
                        .font(.system(size: 15))
                        .foregroundColor(Color(hex: 0x2F6FB5))
                    Text("空调温度")
                        .font(.system(size: 13))
                        .foregroundColor(Color(hex: 0x2B3A4F))
                    Spacer()
                    Button { stepTemp(-1) } label: {
                        Image(systemName: "minus.circle.fill")
                            .font(.system(size: 22)).foregroundColor(Color(hex: 0xB9C7D8))
                    }
                    Text("\(airTemp)°C")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color(hex: 0x1B3A6B))
                        .frame(width: 58)
                    Button { stepTemp(1) } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 22)).foregroundColor(Color(hex: 0x2F6FB5))
                    }
                }
                .padding(.horizontal, 14)
                .frame(height: 50)
                .background(Color.white.opacity(0.9))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                VStack(spacing: 8) {
                    pair("启动发动机", "OpenEngine", "关闭发动机", "CloseEngine")
                    pair("解锁", "UnLockDoor", "关锁", "LockDoor")
                    pair("打开车窗", "OpenWindow", "车窗微开", "WindowSlit")
                    pair("关闭车窗", "CloseWindow", "打开天窗", "OpenDormer")
                    pair("天窗翘起", "SkyWindowLiftUp", "关闭天窗", "CloseDormer")
                    pair("鸣笛", "RemoteSearchCar", "闪灯", "FlashLight")
                    pair("闪灯鸣笛", "Whistle", "关空调", "closeAir")
                }
                .padding(.top, 2)
            }
        }
    }

    private func toolBtn(_ title: String, _ icon: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: icon).font(.system(size: 16)).foregroundColor(KH.blue)
                Text(title).font(.system(size: 10.5)).foregroundColor(Color(hex: 0x2B3A4F))
                    .lineLimit(1).minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 62)
            .background(Color.white.opacity(0.9))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func pair(_ l1: String, _ c1: String, _ l2: String, _ c2: String?) -> some View {
        HStack(spacing: 8) {
            ctrlBtn(l1) { runCmd(c1, l1) }
            if let c2 = c2 {
                ctrlBtn(l2) { runCmd(c2, l2) }
            } else {
                ctrlBtn(l2) { sheet = .history }
            }
        }
    }

    private func ctrlBtn(_ title: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13.5))
                .foregroundColor(Color(hex: 0x2B3A4F))
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Color.white.opacity(0.9))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var footer: some View {
        VStack(spacing: 4) {
            Text("长安开放平台接口 · 指令未完成时其它指令会被拒绝")
                .font(.system(size: 10))
                .foregroundColor(Color(hex: 0x8A94A3))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }

    // MARK: - 车辆切换

    private var carSheet: some View {
        NavigationView {
            List {
                if cars.isEmpty {
                    Text("没有取到车辆列表").foregroundColor(Color(hex: 0x8A94A3))
                } else {
                    ForEach(Array(cars.enumerated()), id: \.offset) { _, row in
                        Button {
                            api.selectCar(row)
                            showCars = false
                            refresh()
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "car.fill")
                                    .foregroundColor(Color(hex: 0x2F6FB5))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text((row["plateNumber"] as? String)
                                         ?? (row["carName"] as? String) ?? "我的爱车")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(Color(hex: 0x2B3A4F))
                                    Text(vinText(row))
                                        .font(.system(size: 10.5))
                                        .foregroundColor(Color(hex: 0x8A94A3))
                                }
                                Spacer()
                                if (row["carId"] as? String) == api.carId {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(Color(hex: 0x2F9E68))
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("选择车辆")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { showCars = false }
                }
            }
        }
    }

    private func vinText(_ row: [String: Any]) -> String {
        let v = (row["vin"] as? String) ?? ""
        let s = (row["seriesName"] as? String) ?? (row["seriesCode"] as? String) ?? ""
        if v.isEmpty { return s }
        return s.isEmpty ? "VIN \(v)" : "\(s) · VIN \(v.suffix(6))"
    }

    // MARK: - 动作

    private func refresh() {
        loading = true
        api.carData { d in
            if let d = d { st = CarState(d) }
            AppGroupStore.syncFromPrefs()
            AppGroupStore.syncCredentials()
            loading = false
        }
    }

    private func loadCars() {
        api.listCars { arr in
            cars = arr
            showCars = true
        }
    }

    private func stepTemp(_ delta: Int) {
        let next = max(16, min(32, airTemp + delta))
        airTemp = next
        api.setTemperature(next) { ok, msg in
            OpLogStore.append(cmd: "空调 \(next)°C", ok: ok, msg: msg)
            toast = ok ? "空调 \(next)°C" : msg
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { toast = nil }
        }
    }

    private func runCmd(_ cmd: String, _ title: String) {
        guard !CarAPI.shared.controlPin.isEmpty else {
            alertMsg = "控车指令要用控车码做 RSA 加密。\n请先在长安 App 确认 6 位安全码，再点右上角「设置控车码」。"
            return
        }
        toast = "正在\(title)…"
        api.control(cmd: cmd) { ok, msg in
            OpLogStore.append(cmd: title, ok: ok, msg: msg)
            toast = nil
            alertMsg = ok ? "已下发：\(title)\n稍等几秒刷新状态" : "\(title)失败：\(msg)"
            if ok { DispatchQueue.main.asyncAfter(deadline: .now() + 2) { refresh() } }
        }
    }

    private func showBtKeyNote() {
        alertMsg = "蓝牙钥匙的 BLE 协议在这份源码里是占位实现：UUID 是 FFF0/FFF1/FFF2，认证算法注释写明「在加固 dex 内，未静态还原」。\niOS 需要真车抓包才能对上，联网控车不受影响。"
    }

    private var pinSheet: some View {
        NavigationView {
            Form {
                Section(header: Text("控车码（长安 App 里的 6 位安全码）")) {
                    TextField("6 位数字", text: $pinInput)
                        .keyboardType(.numberPad)
                }
                Section {
                    Button("保存") {
                        CarAPI.shared.controlPin = pinInput
                        AppGroupStore.syncCredentials()
                        showPinSheet = false
                        toast = "控车码已保存"
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { toast = nil }
                    }
                }
            }
            .navigationTitle("设置控车码")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { showPinSheet = false }
                }
            }
        }
    }

    private func logout() {
        CarAPI.shared.logout()
        st = CarState()
        toast = "已退出登录"
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { showLogin = true }
    }
}

/// 时间戳转 Date：兼容秒级（1.7e9）与毫秒级（1.7e12）
/// 分界必须用 1e11 —— 用 1e9 会把秒级时间戳误当成毫秒，除以 1000 后变成 1970
enum Stamp {
    static func date(_ v: Double) -> Date {
        if v <= 0 { return Date(timeIntervalSince1970: 0) }
        if v > 1e11 { return Date(timeIntervalSince1970: v / 1000) }   // 毫秒
        return Date(timeIntervalSince1970: v)                          // 秒
    }

    static func text(_ v: Double, format: String) -> String {
        if v <= 0 { return "--" }
        let f = DateFormatter()
        f.dateFormat = format
        return f.string(from: date(v))
    }

    static func isValid(_ v: Double) -> Bool {
        guard v > 0 else { return false }
        let t = date(v).timeIntervalSince1970
        return t >= 1_420_070_400 && t <= Date().timeIntervalSince1970 + 30 * 86400
    }
}

enum HomeSheet: String, Identifiable {
    case location, track, photo, more, history, ble
    var id: String { rawValue }
}

// MARK: - 车况数据模型

struct CarState {
    var carName = ""
    var online = false
    var terminalTime = ""
    var fuel = ""
    var fuelPct = 0
    var range = ""
    var odometer = ""
    var voltage = ""
    var outTemp = ""
    var lf = "", rf = "", lr = "", rr = ""
    var doorFL = false, doorFR = false, doorRL = false, doorRR = false
    var lockFL = true, lockFR = true, lockRL = true, lockRR = true
    var trunk = false, hood = false
    var winFL = false, winFR = false, winRL = false, winRR = false
    var series = ""
    var seriesName = ""
    var addr = ""
    var updatedAt = 0
    var vehicleTime = 0
    var terminalRaw = ""
    var sunOpen = false
    var engineOn = false
    var airOn = false

    init() {}

    init(_ d: [String: Any]) {
        func str(_ k: String) -> String {
            if let v = d[k] as? String { return v }
            if let v = d[k] as? Int { return v > 0 ? "\(v)" : "" }
            if let v = d[k] as? Double { return v > 0 ? String(format: "%.0f", v) : "" }
            return ""
        }
        func int(_ k: String) -> Int {
            if let v = d[k] as? Int { return v }
            if let v = d[k] as? Double { return Int(v) }
            return 0
        }
        func flag(_ k: String) -> Bool {
            if let v = d[k] as? Bool { return v }
            return int(k) == 1
        }

        carName = (d["carName"] as? String) ?? ""
        series = (d["series"] as? String) ?? ""
        seriesName = (d["seriesName"] as? String) ?? ""
        range = str("range")
        addr = str("addr")
        updatedAt = int("updatedAt")

        let locked = flag("locked")
        lockFL = locked; lockFR = locked; lockRL = locked; lockRR = locked

        winFL = flag("winFL")
        winFR = flag("winFR")
        winRL = flag("winRL")
        winRR = flag("winRR")
        if !winFL && !winFR && !winRL && !winRR { winFL = flag("winOpen") }

        sunOpen = flag("sunOpen")
        trunk = flag("trunk")
        engineOn = flag("engineOn")
        airOn = flag("airOn")

        lf = str("tpFL"); rf = str("tpFR")
        lr = str("tpRL"); rr = str("tpRR")
        odometer = str("odo")
        voltage = str("volt")
        outTemp = str("outTemp")
        fuel = str("fuel")
        vehicleTime = int("vehicleTime")
        terminalRaw = (d["terminalRaw"] as? String) ?? ""

        doorFL = flag("doorFL"); doorFR = flag("doorFR")
        doorRL = flag("doorRL"); doorRR = flag("doorRR")
        online = !range.isEmpty
    }

    var anyOpen: Bool { doorFL || doorFR || doorRL || doorRR || winFL || winFR || winRL || winRR }
}
