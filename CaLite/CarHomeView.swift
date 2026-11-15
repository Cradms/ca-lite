import SwiftUI
import WidgetKit

/// 首页：按 Android 源码 HomeActivity 1:1 复刻
///
/// 布局顺序与源码一致：车辆卡（车名/续航 + 蓝牙钥匙/刷新）→ 状态两行
/// → 位置卡 → 全宽蓝牙钥匙按钮 → 全景照片/行车轨迹双列
/// → 7 组控车按钮对 → footer
struct CarHomeView: View {
    @State private var st = CarState()
    @State private var loading = true
    @State private var showLogin = false
    @State private var showPinSheet = false
    @State private var pinInput = ""
    @State private var toast: String?
    @State private var alertMsg: String?
    @State private var sheet: HomeSheet?

    private let api = CarAPI.shared

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 8) {
                    carCard
                    locationCard
                    btKeyButton
                    toolButtons
                    controlPairs
                    footer
                }
                .padding(.horizontal, 14)
                .padding(.top, 10)
                .padding(.bottom, 14)
            }
            .background(KH.bg.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            pinInput = CarAPI.shared.controlPin
                            showPinSheet = true
                        } label: { Label("设置控车码", systemImage: "lock.shield") }
                        Button { showLogin = true } label: {
                            Label("重新登录", systemImage: "person.badge.key")
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
                    .background(KH.text.opacity(0.9))
                    .clipShape(Capsule())
                    .padding(.bottom, 30)
                    .transition(.opacity)
            }
        }
        .onAppear {
            if !api.isLoggedIn { showLogin = true } else { refresh() }
        }
        .sheet(isPresented: $showLogin) {
            LoginView {
                showLogin = false
                refresh()
            }
        }
        .sheet(isPresented: $showPinSheet) { pinSheet }
        .sheet(item: $sheet) { s in
            switch s {
            case .location: NavigationView { LocationView() }
            case .track:    NavigationView { TrackView() }
            case .photo:    NavigationView { PhotoView() }
            case .more:     NavigationView { MoreView() }
            case .history:  NavigationView { HistoryView() }
            }
        }
        .alert(isPresented: Binding(get: { alertMsg != nil },
                                    set: { if !$0 { alertMsg = nil } })) {
            Alert(title: Text("提示"), message: Text(alertMsg ?? ""),
                  dismissButton: .default(Text("好")))
        }
    }

    // MARK: 车辆卡
    private var carCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(st.carName.isEmpty ? "我的爱车" : st.carName)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(KH.text)
                        .lineLimit(1)
                    Text("剩余续航：\(st.range.isEmpty ? "--" : st.range) km")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(KH.blue)
                }
                Spacer(minLength: 4)
                HStack(spacing: 6) {
                    smallBtn("蓝牙钥匙") { showBtKeyNote() }
                    smallBtn("刷新") { refresh() }
                }
            }

            stateLine1
                .font(.system(size: 12))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.top, 6)
            stateLine2
                .font(.system(size: 12))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.top, 2)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    /// 第一行：发动机 + 车锁
    private var stateLine1: Text {
        if loading {
            return Text("状态获取中…").foregroundColor(KH.grey)
        }
        let eng = st.engineOn ? "已启动" : "已熄火"
        let locked = st.lockFL
        return Text(eng).foregroundColor(KH.grey)
            + Text(" · ").foregroundColor(KH.grey)
            + Text(locked ? "已锁车" : "未锁车").foregroundColor(locked ? KH.grey : KH.red)
    }

    /// 第二行：逐项列出未关的车窗 / 天窗 / 后备箱
    private var stateLine2: Text {
        if loading { return Text("") }
        var win = ""
        if st.winFL { win += "左前窗" }
        if st.winFR { win += (win.isEmpty ? "" : "、") + "右前窗" }
        if st.winRL { win += (win.isEmpty ? "" : "、") + "左后窗" }
        if st.winRR { win += (win.isEmpty ? "" : "、") + "右后窗" }

        var t = win.isEmpty
            ? Text("车窗已关").foregroundColor(KH.grey)
            : Text(win + "未关").foregroundColor(KH.red)
        t = t + Text(" · ").foregroundColor(KH.grey)
        t = t + Text(st.sunOpen ? "天窗未关" : "天窗已关")
            .foregroundColor(st.sunOpen ? KH.red : KH.grey)
        if st.trunk {
            t = t + Text(" · ").foregroundColor(KH.grey)
                + Text("后备箱未关").foregroundColor(KH.red)
        }
        return t
    }

    // MARK: 位置卡
    private var locationCard: some View {
        Button {
            sheet = .location
        } label: {
            VStack(alignment: .leading, spacing: 3) {
                Text("车辆位置：\(st.addr.isEmpty ? "暂无位置" : st.addr)")
                    .font(.system(size: 13))
                    .foregroundColor(KH.text)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("更新于 \(timeText)")
                    .font(.system(size: 10))
                    .foregroundColor(KH.grey)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var timeText: String {
        guard st.updatedAt > 0 else { return "--" }
        let ms = Double(st.updatedAt)
        let d = Date(timeIntervalSince1970: ms > 1_000_000_000 ? ms / 1000 : ms)
        let f = DateFormatter()
        f.dateFormat = "MM-dd HH:mm"
        return f.string(from: d)
    }

    // MARK: 全宽蓝色按钮
    private var btKeyButton: some View {
        Button { showBtKeyNote() } label: {
            Text("蓝牙钥匙绑定（官方钥匙）")
                .font(.system(size: 14))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 46)
                .background(KH.blue)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .padding(.vertical, 2)
    }

    // MARK: 全景照片 / 行车轨迹
    private var toolButtons: some View {
        HStack(spacing: 8) {
            actionBtn("全景照片") { sheet = .photo }
            actionBtn("行车轨迹") { sheet = .track }
        }
        .padding(.vertical, 2)
    }

    // MARK: 控车按钮对（源码 7 组）
    private var controlPairs: some View {
        VStack(spacing: 8) {
            pair("启动发动机", "OpenEngine", "关闭发动机", "CloseEngine")
            pair("解锁", "UnLockDoor", "关锁", "LockDoor")
            pair("打开车窗", "OpenWindow", "车窗微开", "WindowSlit")
            pair("关闭车窗", "CloseWindow", "打开天窗", "OpenDormer")
            pair("天窗翘起", "SkyWindowLiftUp", "关闭天窗", "CloseDormer")
            pair("鸣笛", "RemoteSearchCar", "闪灯", "FlashLight")
            pair("闪灯鸣笛", "Whistle", "详情", nil)
        }
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

    private var footer: some View {
        Text("长安开放平台接口 · 指令未完成时其它指令会被拒绝")
            .font(.system(size: 10))
            .foregroundColor(KH.grey)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.top, 10)
            .padding(.bottom, 6)
    }

    // MARK: 按钮样式（照源码 dp 值：小按钮 56×32 圆角 8，动作按钮高 46 圆角 10，控车按钮高 52 圆角 10）
    private func smallBtn(_ title: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12))
                .foregroundColor(.white)
                .frame(width: 56, height: 32)
                .background(KH.blue)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func actionBtn(_ title: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 46)
                .background(KH.blue)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func ctrlBtn(_ title: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14))
                .foregroundColor(KH.text)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: - 动作

    private func refresh() {
        loading = true
        api.carData { d in
            DispatchQueue.main.async {
                if let d = d { st = CarState(d) }
                AppGroupStore.syncFromPrefs()
                AppGroupStore.syncCredentials()
                loading = false
            }
        }
    }

    private func runCmd(_ cmd: String, _ title: String) {
        guard !CarAPI.shared.controlPin.isEmpty else {
            alertMsg = "控车指令要用控车码做 RSA 加密。\n请先在长安 App 确认 6 位安全码，再点右上角「设置控车码」。"
            return
        }
        toast = "正在\(title)…"
        api.control(cmd: cmd) { ok, msg in
            DispatchQueue.main.async {
                toast = nil
                alertMsg = ok ? "已下发：\(title)\n稍等几秒刷新状态" : "\(title)失败：\(msg)"
                if ok { DispatchQueue.main.asyncAfter(deadline: .now() + 2) { refresh() } }
            }
        }
    }

    private func showBtKeyNote() {
        alertMsg = "蓝牙钥匙走 BLE 直连车端（Android 端 BleKeyClient 协议），iOS 版未移植。\n联网控车不受影响。"
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

enum HomeSheet: String, Identifiable {
    case location, track, photo, more, history
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
    // 小组件版新增
    var series = ""
    var seriesName = ""
    var addr = ""
    var updatedAt = 0
    var sunOpen = false
    var engineOn = false
    var airOn = false

    init() {}

    /// CarAPI.carData 把缓存拼成扁平字典
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
        online = !range.isEmpty
    }

    var anyOpen: Bool { doorFL || doorFR || doorRL || doorRR || winFL || winFR || winRL || winRR }
}
