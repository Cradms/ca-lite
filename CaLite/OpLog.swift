import Foundation

/// 本机控车记录（源码 HistoryActivity：本机执行结果 + 服务器全量记录）
struct OpLog: Codable, Identifiable {
    var id = UUID()
    var cmd: String
    var ok: Bool
    var msg: String
    var time: Double
}

enum OpLogStore {
    private static let key = "op_log"

    static func append(cmd: String, ok: Bool, msg: String) {
        var arr = load()
        let item = OpLog(cmd: cmd, ok: ok, msg: msg, time: Date().timeIntervalSince1970)
        arr.insert(item, at: 0)
        if arr.count > 50 {
            arr = Array(arr.prefix(50))
        }
        save(arr)
    }

    static func load() -> [OpLog] {
        let text = Prefs.s(key)
        if text.isEmpty { return [] }
        guard let raw = text.data(using: .utf8) else { return [] }
        do {
            let arr = try JSONDecoder().decode([OpLog].self, from: raw)
            return arr
        } catch {
            return []
        }
    }

    static func clear() {
        Prefs.set("", key)
    }

    private static func save(_ arr: [OpLog]) {
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(arr) else { return }
        guard let text = String(data: data, encoding: .utf8) else { return }
        Prefs.set(text, key)
    }
}
