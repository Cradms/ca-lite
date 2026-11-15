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
        arr.insert(OpLog(cmd: cmd, ok: ok, msg: msg, time: Date().timeIntervalSince1970), at: 0)
        if arr.count > 50 { arr = Array(arr.prefix(50)) }
        save(arr)
    }

    static func load() -> [OpLog] {
        guard let raw = Prefs.s(key).data(using: .utf8),
              let arr = try? JSONDecoder().decode([OpLog].self, from: raw) else { return [] }
        return arr
    }

    static func clear() {
        Prefs.set("", key)
    }

    private static func save(_ arr: [OpLog]) {
        guard let d = try? JSONEncoder().encode(arr),
              let s = String(data: d, encoding: .utf8) else { return }
        Prefs.set(s, key)
    }
}
