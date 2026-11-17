import SwiftUI

/// 一次行程（由轨迹点按时间间隔切分而来）
struct CarTrip: Identifiable {
    let id = UUID()
    let start: Date?
    let end: Date?
    let km: Double
    let minutes: Int

    var speed: Double {
        guard minutes > 0, km > 0 else { return 0 }
        return km / (Double(minutes) / 60.0)
    }

    var timeText: String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        guard let s = start else { return "--" }
        let e = end.map { f.string(from: $0) } ?? "--"
        return "\(f.string(from: s)) → \(e)"
    }
}

/// 行程记录：把今日轨迹按停车间隔切成多段，给出每段里程/耗时/均速
struct TripsView: View {
    @State private var trips: [CarTrip] = []
    @State private var loading = true
    @State private var noTime = false
    @State private var err = ""

    private let api = CarAPI.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                if loading {
                    ProgressView("读取轨迹…").padding(.top, 60)
                } else if trips.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "car.side")
                            .font(.system(size: 34)).foregroundColor(C.faint)
                        Text(err.isEmpty ? "今天还没有行程" : err)
                            .font(.system(size: 13)).foregroundColor(C.muted)
                    }
                    .padding(.top, 60)
                } else {
                    summaryCard
                    ForEach(trips) { t in
                        tripCard(t)
                    }
                    if noTime {
                        Text("接口没返回时间戳，只能给出总里程；分段需要时间字段。")
                            .font(.system(size: 10))
                            .foregroundColor(C.faint)
                            .multilineTextAlignment(.center)
                            .padding(.top, 4)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 14)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .background(C.bg.ignoresSafeArea())
        .navigationTitle("今日行程")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { load() } label: {
                    Image(systemName: "arrow.clockwise").foregroundColor(C.blue)
                }
            }
        }
        .onAppear(perform: load)
    }

    // MARK: 汇总

    private var totalKm: Double { trips.reduce(0) { $0 + $1.km } }
    private var totalMin: Int { trips.reduce(0) { $0 + $1.minutes } }

    private var avgSpeed: Double {
        guard totalMin > 0 else { return 0 }
        return totalKm / (Double(totalMin) / 60.0)
    }

    private var summaryCard: some View {
        Card {
            VStack(spacing: 12) {
                HStack(spacing: 0) {
                    metric(String(format: "%.1f", totalKm), "km", "今日里程")
                    vline
                    metric("\(trips.count)", "段", "行程数")
                    vline
                    metric(totalMin > 0 ? "\(totalMin)" : "--", "min", "总耗时")
                    vline
                    metric(avgSpeed > 0 ? String(format: "%.0f", avgSpeed) : "--", "km/h", "平均车速")
                }
            }
        }
    }

    private func metric(_ value: String, _ unit: String, _ title: String) -> some View {
        VStack(spacing: 3) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(C.txt)
                Text(unit)
                    .font(.system(size: 9))
                    .foregroundColor(C.faint)
            }
            Text(title)
                .font(.system(size: 9.5))
                .foregroundColor(C.faint)
        }
        .frame(maxWidth: .infinity)
    }

    private var vline: some View {
        Rectangle().fill(C.bg).frame(width: 1, height: 26)
    }

    // MARK: 单段

    private func tripCard(_ t: CarTrip) -> some View {
        HStack(spacing: 12) {
            VStack(spacing: 2) {
                Image(systemName: "car.fill")
                    .font(.system(size: 15))
                    .foregroundColor(C.blue)
                Text(t.timeText)
                    .font(.system(size: 9.5, design: .monospaced))
                    .foregroundColor(C.faint)
                    .fixedSize()
            }
            .frame(width: 86)

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(String(format: "%.1f", t.km))
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundColor(C.txt)
                    Text("km")
                        .font(.system(size: 10))
                        .foregroundColor(C.faint)
                    Spacer()
                    if t.minutes > 0 {
                        Text("\(t.minutes) 分钟")
                            .font(.system(size: 11))
                            .foregroundColor(C.muted)
                    }
                }
                if t.speed > 0 {
                    Text(String(format: "平均 %.0f km/h", t.speed))
                        .font(.system(size: 10.5))
                        .foregroundColor(C.faint)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: 计算

    private func load() {
        loading = true
        err = ""
        api.trackPointsDetailed { pts in
            loading = false
            guard pts.count > 1 else {
                err = "今天没有轨迹点"
                trips = []
                return
            }
            let hasTime = pts.contains { $0.time != nil }
            noTime = !hasTime

            if !hasTime {
                let km = polylineKm(pts)
                trips = km > 0 ? [CarTrip(start: nil, end: nil, km: km, minutes: 0)] : []
                return
            }

            // 停车超过 5 分钟视为一段行程结束
            var segs: [[CarAPI.TrackPoint]] = []
            var cur: [CarAPI.TrackPoint] = []
            for p in pts {
                if let last = cur.last, let t1 = last.time, let t2 = p.time,
                   t2.timeIntervalSince(t1) > 300 {
                    segs.append(cur)
                    cur = []
                }
                cur.append(p)
            }
            if !cur.isEmpty { segs.append(cur) }

            trips = segs.compactMap { seg in
                guard seg.count > 1 else { return nil }
                let km = polylineKm(seg)
                guard km > 0.05 else { return nil }     // 过滤原地 GPS 抖动
                let s = seg.first?.time
                let e = seg.last?.time
                let mins = Int((e?.timeIntervalSince(s ?? Date()) ?? 0) / 60.0)
                return CarTrip(start: s, end: e, km: km, minutes: max(0, mins))
            }
            if trips.isEmpty { err = "今天没有有效行程（距离过短）" }
        }
    }

    /// 相邻点球面距离累加
    private func polylineKm(_ pts: [CarAPI.TrackPoint]) -> Double {
        guard pts.count > 1 else { return 0 }
        var meters = 0.0
        for i in 1..<pts.count {
            meters += haversine(pts[i - 1], pts[i])
        }
        return meters / 1000.0
    }

    private func haversine(_ a: CarAPI.TrackPoint, _ b: CarAPI.TrackPoint) -> Double {
        let r = 6_371_000.0
        let dLat = (b.lat - a.lat) * .pi / 180
        let dLng = (b.lng - a.lng) * .pi / 180
        let lat1 = a.lat * .pi / 180
        let lat2 = b.lat * .pi / 180
        let h = sin(dLat / 2) * sin(dLat / 2)
            + cos(lat1) * cos(lat2) * sin(dLng / 2) * sin(dLng / 2)
        return 2 * r * asin(min(1, sqrt(h)))
    }
}
