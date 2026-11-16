import SwiftUI

/// 车辆状况（对齐 car-ios 的车辆状态页：续航 / 油量 / 里程 / 电压 / 外温 / 胎压 / 门窗 / 位置）
struct CarStatusView: View {
    @State private var st = CarState()
    @State private var loading = true
    @State private var showMap = false
    @State private var showRaw = false

    private let api = CarAPI.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                header
                if loading {
                    ProgressView().padding(.vertical, 40)
                } else {
                    overviewCard
                    tyreCard
                    bodyCard
                    locationCard
                    timeCard
                    rawCard
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 8)
            .padding(.bottom, 20)
        }
        .background(KH.bg.ignoresSafeArea())
        .navigationTitle("车况")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { load() } label: {
                    Image(systemName: "arrow.clockwise").foregroundColor(KH.blue)
                }
            }
        }
        .onAppear(perform: load)
        .sheet(isPresented: $showMap) {
            NavigationView { LocationView() }
        }
    }

    // MARK: 顶部

    private var header: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text(st.carName.isEmpty ? "我的爱车" : st.carName)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(Color(hex: 0x1B3A6B))
                    .lineLimit(1)
                Text(modelTitle)
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: 0x6E7A8A))
            }
            Spacer()
            Image(carImage)
                .resizable()
                .scaledToFit()
                .frame(height: 56)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.95))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var modelTitle: String {
        let code = CarModel.normalize(st.seriesName.isEmpty ? st.series : st.seriesName)
        let n = CarModel.name(code)
        if !n.isEmpty { return n }
        return st.seriesName
    }

    private var carImage: String {
        let code = CarModel.normalize(st.seriesName.isEmpty ? st.series : st.seriesName)
        return code.isEmpty ? "car" : "car_" + code.lowercased()
    }

    // MARK: 概览

    private var overviewCard: some View {
        VStack(spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(st.range.isEmpty ? "--" : st.range)
                    .font(.system(size: 38, weight: .bold))
                    .foregroundColor(Color(hex: 0x1B3A6B))
                Text("km 剩余续航")
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: 0x6E7A8A))
                Spacer()
            }

            Divider()

            HStack(spacing: 0) {
                metric("油量", st.fuel.isEmpty ? "--" : st.fuel, "L")
                vline
                metric("总里程", st.odometer.isEmpty ? "--" : st.odometer, "km")
                vline
                metric("电压", st.voltage.isEmpty ? "--" : st.voltage, "V")
                vline
                metric("外温", st.outTemp.isEmpty ? "--" : st.outTemp, "°C")
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.95))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func metric(_ title: String, _ value: String, _ unit: String) -> some View {
        VStack(spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color(hex: 0x1B3A6B))
                Text(unit)
                    .font(.system(size: 9))
                    .foregroundColor(Color(hex: 0x8A94A3))
            }
            Text(title)
                .font(.system(size: 10))
                .foregroundColor(Color(hex: 0x8A94A3))
        }
        .frame(maxWidth: .infinity)
    }

    private var vline: some View {
        Rectangle().fill(Color(hex: 0xE3EAF3)).frame(width: 1, height: 28)
    }

    // MARK: 胎压

    private var tyreCard: some View {
        VStack(spacing: 10) {
            HStack {
                Text("胎压")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color(hex: 0x6E7A8A))
                Spacer()
                Text("正常 230–260 kPa")
                    .font(.system(size: 10))
                    .foregroundColor(Color(hex: 0x8A94A3))
            }
            HStack(spacing: 0) {
                tyre("左前", st.lf)
                vline
                tyre("右前", st.rf)
                vline
                tyre("左后", st.lr)
                vline
                tyre("右后", st.rr)
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.95))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func tyre(_ pos: String, _ v: String) -> some View {
        let n = Double(v) ?? 0
        let warn = n > 0 && (n < 200 || n > 280)
        return VStack(spacing: 4) {
            Text(v.isEmpty ? "--" : v)
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(warn ? Color(hex: 0xE53935) : Color(hex: 0x1B3A6B))
            Text(pos)
                .font(.system(size: 10))
                .foregroundColor(Color(hex: 0x8A94A3))
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: 车身状态

    private var bodyCard: some View {
        VStack(spacing: 0) {
            ForEach(Array(bodyItems.enumerated()), id: \.offset) { i, item in
                row(item.0, item.1, item.2)
                if i < bodyItems.count - 1 { sep }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
        .background(Color.white.opacity(0.95))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    /// 车身状态行（数据驱动，避免 ViewBuilder 超过 10 个子视图）
    private var bodyItems: [(String, String, Color)] {
        [
            ("车锁", st.lockFL ? "已锁车" : "未锁车", st.lockFL ? okColor : badColor),
            ("车门", doorText, doorText == "全部关闭" ? okColor : badColor),
            ("车窗", winText, winText == "全部关闭" ? okColor : badColor),
            ("天窗", st.sunOpen ? "未关" : "已关", st.sunOpen ? badColor : okColor),
            ("后备箱", st.trunk ? "未关" : "已关", st.trunk ? badColor : okColor),
            ("发动机", st.engineOn ? "运行中" : "已熄火", st.engineOn ? Color(hex: 0x2F6FB5) : okColor),
            ("空调", st.airOn ? "开启" : "关闭", st.airOn ? Color(hex: 0x2F6FB5) : Color(hex: 0x8A94A3))
        ]
    }

    private var okColor: Color { Color(hex: 0x2F9E68) }
    private var badColor: Color { Color(hex: 0xE53935) }

    private var doorText: String {
        var arr: [String] = []
        if st.doorFL { arr.append("主驾") }
        if st.doorFR { arr.append("副驾") }
        if st.doorRL { arr.append("左后") }
        if st.doorRR { arr.append("右后") }
        return arr.isEmpty ? "全部关闭" : arr.joined(separator: "、") + " 开启"
    }

    private var winText: String {
        var arr: [String] = []
        if st.winFL { arr.append("左前") }
        if st.winFR { arr.append("右前") }
        if st.winRL { arr.append("左后") }
        if st.winRR { arr.append("右后") }
        return arr.isEmpty ? "全部关闭" : arr.joined(separator: "、") + " 开启"
    }

    private func row(_ title: String, _ value: String, _ color: Color) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 13))
                .foregroundColor(Color(hex: 0x2B3A4F))
            Spacer()
            Text(value)
                .font(.system(size: 12.5, weight: .medium))
                .foregroundColor(color)
        }
        .frame(height: 40)
    }

    private var sep: some View {
        Rectangle().fill(Color(hex: 0xF0F4F9)).frame(height: 1)
    }

    // MARK: 位置 / 时间

    private var locationCard: some View {
        Button { showMap = true } label: {
            HStack(spacing: 8) {
                Image(systemName: "location.fill")
                    .font(.system(size: 12))
                    .foregroundColor(KH.blue)
                Text(st.addr.isEmpty ? "暂无位置" : st.addr)
                    .font(.system(size: 12.5))
                    .foregroundColor(Color(hex: 0x2B3A4F))
                    .lineLimit(1)
                Spacer(minLength: 4)
                Image(systemName: "chevron.right")
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: 0xA9B3BE))
            }
            .padding(.horizontal, 16)
            .frame(height: 46)
            .background(Color.white.opacity(0.95))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var timeCard: some View {
        VStack(spacing: 4) {
            Text((!st.terminalRaw.isEmpty || st.vehicleTime > 0) ? "车辆上报时间" : "本机刷新时间")
                .font(.system(size: 10))
                .foregroundColor(Color(hex: 0x8A94A3))
            Text(timeText)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Color(hex: 0x2B3A4F))
            let raw = Prefs.s("c_traw")
            if !raw.isEmpty {
                Text("terminalTime = \(raw)")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(Color(hex: 0x8A94A3))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var timeText: String {
        if !st.terminalRaw.isEmpty { return st.terminalRaw }
        let stamp = st.vehicleTime > 0 ? st.vehicleTime : st.updatedAt
        return Stamp.text(Double(stamp), format: "yyyy-MM-dd HH:mm:ss")
    }

    // MARK: 原始车况（调试）

    private var rawCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(.easeInOut(duration: 0.15)) { showRaw.toggle() }
            } label: {
                HStack {
                    Text("原始车况数据")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color(hex: 0x6E7A8A))
                    Spacer()
                    Text(showRaw ? "收起" : "展开")
                        .font(.system(size: 11))
                        .foregroundColor(Color(hex: 0x8A94A3))
                    Image(systemName: showRaw ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10))
                        .foregroundColor(Color(hex: 0x8A94A3))
                }
            }
            .buttonStyle(.plain)

            if showRaw {
                let raw = Prefs.s("c_raw")
                ScrollView([.horizontal, .vertical]) {
                    Text(raw.isEmpty ? "暂无数据，先点右上角刷新一次" : raw)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(Color(hex: 0x2B3A4F))
                        .textSelection(.enabled)
                }
                .frame(maxHeight: 300)

                Button {
                    UIPasteboard.general.string = raw
                } label: {
                    Text("复制全部")
                        .font(.system(size: 11.5))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 32)
                        .background(Color(hex: 0x6E7A8A))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.95))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: 加载

    private func load() {
        loading = true
        api.carData { d in
            if let d = d { st = CarState(d) }
            AppGroupStore.syncFromPrefs()
            loading = false
        }
    }
}
