import Foundation

/// 车况缓存同步（原小组件共享层，现已移除小组件，只保留本地缓存写入）
enum AppGroupStore {

    /// 兼容旧调用：无小组件后不再需要 App Group
    static var groupAvailable: Bool { false }

    static var defaults: UserDefaults { Prefs.d }

    static func set(_ v: String, _ k: String) { Prefs.set(v, k) }
    static func get(_ k: String, _ def: String = "") -> String { Prefs.s(k, def) }

    /// 把车况写进缓存（界面与下次启动复用）
    static func syncFromPrefs() {
        defaults.set(Prefs.i("c_range"), forKey: "w_range")
        defaults.set(Prefs.b("c_locked") ? 1 : 0, forKey: "w_locked")
        defaults.set(Prefs.b("c_win") ? 1 : 0, forKey: "w_win")
        defaults.set(Prefs.b("c_sun") ? 1 : 0, forKey: "w_sun")
        defaults.set(Prefs.s("c_addr"), forKey: "w_addr")
        defaults.set(Double(Prefs.l("c_upd")) / 1000.0, forKey: "w_at")
        defaults.synchronize()
    }

    /// 凭据落盘（切车、登录后刷新界面用）
    static func syncCredentials() {
        let api = CarAPI.shared
        Prefs.set(api.token, "w_token")
        Prefs.set(api.mRefresh, "w_rt")
        Prefs.set(api.carId, "w_cid")
        Prefs.set(api.controlPin, "w_pin")
        Prefs.seti(api.isLoggedIn ? 1 : 0, "w_logged")
        defaults.synchronize()
    }
}
