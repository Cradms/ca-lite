import WidgetKit
import SwiftUI

// MARK: - 共享存储（App Group）

enum Shared {
    static let group = "group.com.yg.calite"

    /// App Group 不可用（自签丢了 entitlements）时为 nil，读到的全是空
    static var groupUsable: Bool { UserDefaults(suiteName: group) != nil }

    static var defaults: UserDefaults {
        UserDefaults(suiteName: group) ?? .standard
    }

    static func str(_ k: String) -> String { defaults.string(forKey: k) ?? "" }

    static var logged: Bool { defaults.integer(forKey: "w_logged") == 1 }

    static var carName: String {
        let v = str("w_car")
        return v.isEmpty ? "我的爱车" : v
    }

    static var range: String {
        let n = defaults.integer(forKey: "w_range")
        return n > 0 ? "\(n)" : "--"
    }

    static var locked: Bool { defaults.integer(forKey: "w_locked") == 1 }
    static var winOpen: Bool { defaults.integer(forKey: "w_win") == 1 }
    static var sunOpen: Bool { defaults.integer(forKey: "w_sun") == 1 }
    static var engineOn: Bool { defaults.integer(forKey: "w_engine") == 1 }
    static var addr: String { str("w_addr") }

    static var tpFL: Int { defaults.integer(forKey: "w_tp_fl") }
    static var tpFR: Int { defaults.integer(forKey: "w_tp_fr") }
    static var tpRL: Int { defaults.integer(forKey: "w_tp_rl") }
    static var tpRR: Int { defaults.integer(forKey: "w_tp_rr") }

    static var updated: Date {
        let t = defaults.double(forKey: "w_at")
        return t > 0 ? Date(timeIntervalSince1970: t) : Date(timeIntervalSince1970: 0)
    }

    // 车型：优先 seriesName，其次 seriesCode
    static var series: String { str("w_series") }
    static var seriesName: String { str("w_series_name") }

    static func normalize(_ s: String) -> String {
        let u = s.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if u.isEmpty { return "" }
        if u.contains("逸动") && u.contains("PLUS") { return "C211" }
        if u.contains("启源") && u.contains("A07") { return "C236" }
        if u.contains("UNI-V") { return "C281" }
        if u.contains("启源") && u.contains("A06") { return "C281_P" }
        if u.contains("逸达") { return "C589" }
        if u.contains("启源") && u.contains("A05") { return "C589_P" }
        if u.contains("UNI-K") { return "CD569" }
        if u.contains("UNI-T") { return "S202" }
        if u.contains("CS55") { return "S203" }
        if u.contains("启源") && u.contains("Q05") { return "S203_P" }
        if u.contains("CS75") {
            if u.contains("四代") { return "S311MCA" }
            if u.contains("三代") { return "S311_P" }
            return "S311"
        }
        if u == "C211-1" { return "C211" }
        var v = u
        if let d = v.firstIndex(of: "-"), d != v.startIndex { v = String(v[v.startIndex..<d]) }
        let codes: Set<String> = ["C211", "C236", "C281", "C281_P", "C589", "C589_P",
                                  "CD569", "S202", "S203", "S203_P", "S311", "S311_P", "S311MCA"]
        return codes.contains(v) ? v : ""
    }

    static var modelCode: String {
        let a = normalize(seriesName)
        return a.isEmpty ? normalize(series) : a
    }

    static var carImage: String {
        let c = modelCode
        return c.isEmpty ? "car" : "car_" + c.lowercased()
    }

    static var modelTitle: String {
        switch modelCode {
        case "C211": return "逸动 PLUS"
        case "C236": return "启源 A07"
        case "C281": return "UNI-V"
        case "C281_P": return "启源 A06"
        case "C589": return "逸达 / 逸动"
        case "C589_P": return "启源 A05"
        case "CD569": return "UNI-K"
        case "S202": return "UNI-T"
        case "S203": return "CS55 Plus"
        case "S203_P": return "启源 Q05"
        case "S311": return "CS75 Plus 二代"
        case "S311_P": return "CS75 Plus 三代"
        case "S311MCA": return "CS75 Plus 四代"
        default: return seriesName
        }
    }
}

// MARK: - 数据

struct Entry: TimelineEntry {
    let date: Date
    let carName: String
    let modelTitle: String
    let carImage: String
    let range: String
    let locked: Bool
    let winOpen: Bool
    let sunOpen: Bool
    let engineOn: Bool
    let addr: String
    let tpFL: Int
    let tpFR: Int
    let tpRL: Int
    let tpRR: Int
    let updated: Date
    let logged: Bool
    let groupUsable: Bool
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> Entry { sample }

    func getSnapshot(in context: Context, completion: @escaping (Entry) -> Void) {
        completion(current())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        // 先自己拉一次车况，再出 Entry；网络失败也用缓存出
        WidgetAPI.refresh {
            let e = self.current()
            let next = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date()
            completion(Timeline(entries: [e], policy: .after(next)))
        }
    }

    private var sample: Entry {
        Entry(date: Date(), carName: "川 QQQ318", modelTitle: "UNI-V",
              carImage: "car_c281", range: "567", locked: true, winOpen: false,
              sunOpen: false, engineOn: false, addr: "四川省达州市渠县渠江街道长德路",
              tpFL: 237, tpFR: 237, tpRL: 241, tpRR: 238,
              updated: Date(), logged: true, groupUsable: true)
    }

    private func current() -> Entry {
        Entry(date: Date(),
              carName: Shared.carName,
              modelTitle: Shared.modelTitle,
              carImage: Shared.carImage,
              range: Shared.range,
              locked: Shared.locked,
              winOpen: Shared.winOpen,
              sunOpen: Shared.sunOpen,
              engineOn: Shared.engineOn,
              addr: Shared.addr,
              tpFL: Shared.tpFL, tpFR: Shared.tpFR,
              tpRL: Shared.tpRL, tpRR: Shared.tpRR,
              updated: Shared.updated,
              logged: Shared.logged,
              groupUsable: Shared.groupUsable)
    }
}

// MARK: - 视图

struct CaLiteWidgetEntryView: View {
    var entry: Entry
    @Environment(\.widgetFamily) var family

    private let blue = Color(red: 0x2F/255, green: 0x6F/255, blue: 0xB5/255)
    private let green = Color(red: 0x2F/255, green: 0x9E/255, blue: 0x68/255)
    private let red = Color(red: 0xE5/255, green: 0x39/255, blue: 0x35/255)
    private let txt = Color(red: 0x1B/255, green: 0x3A/255, blue: 0x6B/255)
    private let muted = Color(red: 0x6E/255, green: 0x7A/255, blue: 0x8A/255)
    private let faint = Color(red: 0x8A/255, green: 0x94/255, blue: 0xA3/255)

    var body: some View {
        Group {
            if !entry.logged {
                notLogged
            } else {
                switch family {
                case .systemSmall: smallView
                case .systemLarge: largeView
                default: mediumView
                }
            }
        }
        .widgetBackground(
            LinearGradient(colors: [Color.white,
                                    Color(red: 0xE8/255, green: 0xF0/255, blue: 0xFA/255)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        // 整块点击打开 App（不在 widget 内控车）
        .widgetURL(URL(string: "calite://open"))
    }

    // 未登录 / App Group 不可用
    private var notLogged: some View {
        VStack(spacing: 6) {
            Image(systemName: entry.groupUsable ? "car.fill" : "exclamationmark.triangle.fill")
                .font(.system(size: 22))
                .foregroundColor(entry.groupUsable ? blue.opacity(0.5) : red.opacity(0.8))
            Text(entry.groupUsable ? "打开 CA Lite 登录" : "App Group 不可用")
                .font(.system(size: 11.5, weight: .medium))
                .foregroundColor(muted)
                .multilineTextAlignment(.center)
            Text(entry.groupUsable ? "点一下进入 App" : "换 TrollStore 安装或补签名")
                .font(.system(size: 9))
                .foregroundColor(faint)
                .multilineTextAlignment(.center)
        }
        .padding(8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // 小尺寸
    private var smallView: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Circle().fill(entry.locked ? green : red)
                    .frame(width: 5, height: 5)
                Text(entry.carName)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(txt)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Spacer(minLength: 0)
            }

            Spacer(minLength: 0)

            Image(entry.carImage)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
                .frame(height: 40)

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(entry.range)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(txt)
                Text("km")
                    .font(.system(size: 9))
                    .foregroundColor(muted)
            }
            Text("剩余续航")
                .font(.system(size: 8.5))
                .foregroundColor(faint)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    // 中尺寸
    private var mediumView: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                Text(entry.carName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(txt)
                    .lineLimit(1)
                if !entry.modelTitle.isEmpty {
                    Text(entry.modelTitle)
                        .font(.system(size: 9))
                        .foregroundColor(faint)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                statusTag
            }

            HStack(alignment: .center, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text(entry.range)
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(txt)
                        Text("km")
                            .font(.system(size: 10))
                            .foregroundColor(muted)
                    }
                    Text("剩余续航")
                        .font(.system(size: 9))
                        .foregroundColor(faint)
                }
                Spacer(minLength: 0)
                Image(entry.carImage)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 54)
            }

            Divider().opacity(0.5)

            HStack(spacing: 0) {
                miniStat("车锁", entry.locked ? "已锁" : "未锁",
                         entry.locked ? green : red)
                miniDivider
                miniStat("车窗", entry.winOpen ? "未关" : "已关",
                         entry.winOpen ? red : green)
                miniDivider
                miniStat("天窗", entry.sunOpen ? "未关" : "已关",
                         entry.sunOpen ? red : green)
                miniDivider
                miniStat("更新", shortTime, faint)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    // 大尺寸
    private var largeView: some View {
        VStack(alignment: .leading, spacing: 8) {
            mediumView

            Divider()

            HStack(spacing: 0) {
                tyre("左前", entry.tpFL)
                miniDivider
                tyre("右前", entry.tpFR)
                miniDivider
                tyre("左后", entry.tpRL)
                miniDivider
                tyre("右后", entry.tpRR)
            }

            if !entry.addr.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "location.fill")
                        .font(.system(size: 8))
                        .foregroundColor(blue)
                    Text(entry.addr)
                        .font(.system(size: 9))
                        .foregroundColor(muted)
                        .lineLimit(1)
                }
            }

            Text("点一下打开 CA Lite")
                .font(.system(size: 8))
                .foregroundColor(faint)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private var statusTag: some View {
        Text(entry.locked ? "已锁车" : "未锁车")
            .font(.system(size: 9, weight: .medium))
            .foregroundColor(entry.locked ? green : red)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background((entry.locked ? green : red).opacity(0.12))
            .clipShape(Capsule())
    }

    private func miniStat(_ title: String, _ value: String, _ color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(color)
            Text(title)
                .font(.system(size: 8))
                .foregroundColor(faint)
        }
        .frame(maxWidth: .infinity)
    }

    private func tyre(_ pos: String, _ v: Int) -> some View {
        let warn = v > 0 && (v < 200 || v > 280)
        return VStack(spacing: 2) {
            Text(v > 0 ? "\(v)" : "--")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(warn ? red : txt)
            Text(pos)
                .font(.system(size: 8))
                .foregroundColor(faint)
        }
        .frame(maxWidth: .infinity)
    }

    private var miniDivider: some View {
        Rectangle()
            .fill(Color(red: 0xE3/255, green: 0xEA/255, blue: 0xF3/255))
            .frame(width: 1, height: 22)
    }

    private var shortTime: String {
        guard entry.updated.timeIntervalSince1970 > 0 else { return "--" }
        let f = DateFormatter()
        f.dateFormat = "MM.dd HH:mm"
        return f.string(from: entry.updated)
    }
}

// MARK: - Widget 背景兼容

extension View {
    @ViewBuilder
    func widgetBackground<S: ShapeStyle>(_ bg: S) -> some View {
        if #available(iOS 17.0, *) {
            containerBackground(bg, for: .widget)
        } else {
            background(bg)
        }
    }
}

// MARK: - 声明

@main
struct CaLiteWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "CaLiteWidget", provider: Provider()) { entry in
            CaLiteWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("CA Lite 车况")
        .description("车牌、续航、门锁、胎压；点一下打开 App")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
