import Foundation
import WidgetKit

/// 主 App → 小组件 共享状态（App Group）
enum AppGroupStore {

    static let group = Prefs.group

    static var defaults: UserDefaults { Prefs.d }

    /// App Group 容器里的文件通道（UserDefaults 跨进程不可靠时的备份）
    static var stateURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group)?
            .appendingPathComponent("widget_state.json")
    }


    /// App Group 是否真的可用（自签时 entitlements 掉了就会 false，小组件读不到数据）
    static var groupAvailable: Bool {
        UserDefaults(suiteName: group) != nil
    }

    static func set(_ v: String, _ k: String) { Prefs.set(v, k) }

    static func get(_ k: String, _ def: String = "") -> String { Prefs.s(k, def) }

    /// 把 CarAPI 缓存的车况镜像给小组件
    static func syncFromPrefs() {
        let api = CarAPI.shared
        defaults.set(Prefs.i("c_range"), forKey: "w_range")
        defaults.set(Prefs.b("c_locked") ? 1 : 0, forKey: "w_locked")
        defaults.set(Prefs.b("c_win") ? 1 : 0, forKey: "w_win")
        defaults.set(Prefs.b("c_sun") ? 1 : 0, forKey: "w_sun")
        defaults.set(Prefs.b("c_engine") ? 1 : 0, forKey: "w_engine")
        defaults.set(Prefs.b("c_air") ? 1 : 0, forKey: "w_air")
        defaults.set(Prefs.s("c_addr"), forKey: "w_addr")
        defaults.set(api.carSeries, forKey: "w_series")
        defaults.set(api.carSeriesName.isEmpty ? CarModel.name(api.carSeries) : api.carSeriesName,
                     forKey: "w_series_name")
        defaults.set(api.carName, forKey: "w_car")
        defaults.set(Double(Prefs.l("c_upd")) / 1000.0, forKey: "w_at")
        defaults.set(api.isLoggedIn ? 1 : 0, forKey: "w_logged")
        defaults.set(Prefs.i("c_tp_fl"), forKey: "w_tp_fl")
        defaults.set(Prefs.i("c_tp_fr"), forKey: "w_tp_fr")
        defaults.set(Prefs.i("c_tp_rl"), forKey: "w_tp_rl")
        defaults.set(Prefs.i("c_tp_rr"), forKey: "w_tp_rr")

        defaults.synchronize()
        writeStateFile()
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// 凭证同步（小组件点按钮发指令要用）
    static func syncCredentials() {
        let api = CarAPI.shared
        Prefs.set(api.token, "w_token")
        Prefs.set(api.mRefresh, "w_rt")
        Prefs.set(api.carId, "w_cid")
        Prefs.set(api.controlPin, "w_pin")
        Prefs.seti(api.isLoggedIn ? 1 : 0, "w_logged")
        Prefs.d.synchronize()
    }

    // MARK: - 读取（小组件侧）

    static var range: Int { defaults.integer(forKey: "w_range") }
    static var locked: Bool { defaults.integer(forKey: "w_locked") == 1 }
    static var winOpen: Bool { defaults.integer(forKey: "w_win") == 1 }
    static var engineOn: Bool { defaults.integer(forKey: "w_engine") == 1 }
    static var series: String { defaults.string(forKey: "w_series") ?? "" }
    static var seriesName: String { defaults.string(forKey: "w_series_name") ?? "" }
    static var carName: String { defaults.string(forKey: "w_car") ?? "我的爱车" }
    static var addr: String { defaults.string(forKey: "w_addr") ?? "" }
    static var logged: Bool { defaults.integer(forKey: "w_logged") == 1 }
    static var updatedAt: Date {
        let t = defaults.double(forKey: "w_at") / 1000.0
        return t > 0 ? Date(timeIntervalSince1970: t) : Date(timeIntervalSince1970: 0)
    }

    static var carImageName: String {
        let code = CarModel.normalize(seriesName.isEmpty ? series : seriesName)
        return code.isEmpty ? "car" : "car_" + code.lowercased()
    }

    static var modelTitle: String {
        let n = CarModel.name(CarModel.normalize(seriesName.isEmpty ? series : seriesName))
        if !n.isEmpty { return n }
        return seriesName.isEmpty ? "我的爱车" : seriesName
    }

    /// 把小组件需要的字段落成 JSON 文件
    private static func writeStateFile() {
        guard let url = stateURL else { return }
        let api = CarAPI.shared
        let dict: [String: Any] = [
            "logged": api.isLoggedIn ? 1 : 0,
            "car": api.carName,
            "series": api.carSeries,
            "series_name": api.carSeriesName,
            "range": Prefs.i("c_range"),
            "locked": Prefs.b("c_locked") ? 1 : 0,
            "win": Prefs.b("c_win") ? 1 : 0,
            "sun": Prefs.b("c_sun") ? 1 : 0,
            "engine": Prefs.b("c_engine") ? 1 : 0,
            "addr": Prefs.s("c_addr"),
            "tp_fl": Prefs.i("c_tp_fl"), "tp_fr": Prefs.i("c_tp_fr"),
            "tp_rl": Prefs.i("c_tp_rl"), "tp_rr": Prefs.i("c_tp_rr"),
            "at": Double(Prefs.l("c_upd")) / 1000.0
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: dict) else { return }
        try? data.write(to: url, options: .atomic)
    }
}
