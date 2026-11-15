import Foundation
import WidgetKit

/// 小组件自己拉车况（不依赖主 App 打开过）
///
/// 只在 App Group 里有 token / carId 时才会请求；拉完写回 w_* 供视图读取。
enum WidgetAPI {

    static let host = "https://m.iov.changan.com.cn"

    static func refresh(done: @escaping () -> Void) {
        let token = Shared.str("w_token")
        let carId = Shared.str("w_cid")
        guard !token.isEmpty, !carId.isEmpty else {
            Shared.defaults.set(0, forKey: "w_logged")
            done()
            return
        }
        Shared.defaults.set(1, forKey: "w_logged")

        var comps = URLComponents(string: host + "/app2/api/car/data")!
        comps.queryItems = [
            URLQueryItem(name: "carId", value: carId),
            URLQueryItem(name: "ErrorAutoProjectile", value: "false"),
            URLQueryItem(name: "toast", value: "false"),
            URLQueryItem(name: "keys", value: "*"),
            URLQueryItem(name: "token", value: token),
            URLQueryItem(name: "isNev", value: "0")
        ]
        guard let url = comps.url else { done(); return }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.timeoutInterval = 15
        req.setValue("application/x-www-form-urlencoded; charset=UTF-8",
                     forHTTPHeaderField: "Content-Type")
        req.setValue("application/json, text/plain, */*", forHTTPHeaderField: "Accept")
        req.setValue("inCall", forHTTPHeaderField: "vcs-app-id")
        req.httpBody = Data()

        let task = URLSession.shared.dataTask(with: req) { data, _, _ in
            if let data = data,
               let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                apply(obj)
            }
            done()
        }
        task.resume()
    }

    // MARK: - 解析并写回共享存储

    private static func apply(_ root: [String: Any]) {
        var d: [String: Any] = (root["data"] as? [String: Any]) ?? [:]
        if d.isEmpty, let s = root["data"] as? String, s.hasPrefix("{"),
           let raw = s.data(using: .utf8),
           let o = try? JSONSerialization.jsonObject(with: raw) as? [String: Any] {
            d = o
        }
        guard !d.isEmpty else { return }
        for wrap in ["data", "carCondition", "carData", "result"] {
            if let inner = d[wrap] as? [String: Any] { d = inner }
        }

        func num(_ keys: [String]) -> Double {
            for k in keys {
                if let v = d[k] as? Double { return v }
                if let v = d[k] as? Int { return Double(v) }
                if let v = d[k] as? String, let x = Double(v) { return x }
            }
            return -1
        }
        func flag(_ keys: [String]) -> Int {
            let v = num(keys)
            return v < 0 ? -1 : (v == 1 ? 1 : 0)
        }
        func anyOpen(_ prefix: String) -> Int {
            var seen = false
            for (k, v) in d where k.lowercased().contains(prefix.lowercased()) {
                seen = true
                let sv = "\(v)".lowercased()
                if sv == "1" || sv == "true" || sv == "on" || sv.contains("open") { return 1 }
            }
            return seen ? 0 : -1
        }

        let def = Shared.defaults

        var range = num(["totalResidualMileage"])
        if range <= 0 { range = num(["remainedPowerMile"]) }
        if range <= 0 { range = num(["remainedOilMile"]) }
        if range <= 0 { range = num(["enduranceMileage"]) }
        if range <= 0 { range = num(["range"]) }
        if range > 0 { def.set(Int(range), forKey: "w_range") }

        let fl = flag(["driverDoorLock"]), fr = flag(["passengerDoorLock"])
        let rl = flag(["leftRearDoorLock"]), rr = flag(["rightRearDoorLock"])
        if fl >= 0 || fr >= 0 || rl >= 0 || rr >= 0 {
            let anyUnlock = fl == 1 || fr == 1 || rl == 1 || rr == 1
            def.set(anyUnlock ? 0 : 1, forKey: "w_locked")
        }

        let wFl = flag(["diverWindow"]), wFr = flag(["passengerWindow"])
        let wRl = flag(["leftRearWindow"]), wRr = flag(["rightRearWindow"])
        if wFl >= 0 || wFr >= 0 || wRl >= 0 || wRr >= 0 {
            let anyWin = wFl == 1 || wFr == 1 || wRl == 1 || wRr == 1
            def.set(anyWin ? 1 : 0, forKey: "w_win")
        }

        let sun = anyOpen("sunroof"); if sun >= 0 { def.set(sun, forKey: "w_sun") }
        let eng = flag(["engineStatus", "fireStatus"])
        if eng >= 0 { def.set(eng == 1 || eng == 2 ? 1 : 0, forKey: "w_engine") }
        let air = flag(["airStatus"]); if air >= 0 { def.set(air, forKey: "w_air") }

        let tpFl = Int(num(["lfTyrePressure", "flTyrePressure"]).rounded())
        let tpFr = Int(num(["rfTyrePressure", "frTyrePressure"]).rounded())
        if tpFl > 0 { def.set(tpFl, forKey: "w_tp_fl") }
        if tpFr > 0 { def.set(tpFr, forKey: "w_tp_fr") }

        // 车型
        var series = (d["seriesCode"] as? String) ?? ""
        if series.isEmpty { series = (d["carSeriesCode"] as? String) ?? "" }
        var name = (d["carName"] as? String) ?? ""
        if name.isEmpty { name = (d["seriesName"] as? String) ?? "" }
        if !series.isEmpty { def.set(series, forKey: "w_series") }
        if !name.isEmpty { def.set(name, forKey: "w_series_name") }

        def.set(Double(Date().timeIntervalSince1970), forKey: "w_at")
    }
}
