import SwiftUI

/// 控车诊断：显示 v5 / v3 每一步的真实响应，便于定位 1004 之类的服务端拒绝
struct ControlDiagView: View {
    @State private var trace = ""
    @State private var toast: String?
    @State private var pinTokenInput = ""
    @State private var devInput = ""

    private let api = CarAPI.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                envCard
                traceCard
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 14)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .background(C.bg.ignoresSafeArea())
        .navigationTitle("控车诊断")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    trace = Prefs.s("ctl_trace")
                    toast = "已刷新"
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { toast = nil }
                } label: {
                    Image(systemName: "arrow.clockwise").foregroundColor(C.blue)
                }
            }
        }
        .overlay(alignment: .bottom) {
            if let t = toast {
                Text(t)
                    .font(.system(size: 12))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(C.txt.opacity(0.9))
                    .clipShape(Capsule())
                    .padding(.bottom, 24)
            }
        }
        .onAppear {
            trace = Prefs.s("ctl_trace")
            pinTokenInput = Prefs.s("pin_token")
            devInput = Prefs.s("dev_override")
        }
    }

    private var envCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("当前环境")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(C.blue)
                .padding(.bottom, 6)

            line("控车码", api.controlPin.isEmpty ? "未设置" : "已设置（\(api.controlPin.count) 位）",
                 api.controlPin.isEmpty ? C.red : C.green)
            sep
            line("deviceId", api.deviceId, C.muted)
            sep
            line("carId", String(api.carId.prefix(8)) + (api.carId.isEmpty ? " 未登录" : "…"), C.muted)
            sep
            line("最近一次指令", Prefs.l("last_cmd_at") > 0 ? agoText : "无", C.muted)
            sep
            devRow
            sep
            pinTokenRow

            HStack(spacing: 10) {
                Button {
                    UIPasteboard.general.string = trace
                    toast = "已复制"
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { toast = nil }
                } label: {
                    Text("复制日志")
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity).frame(height: 36)
                        .background(C.blue)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)

                Button {
                    CarAPI.clearTrace()
                    trace = ""
                } label: {
                    Text("清空")
                        .font(.system(size: 12.5))
                        .foregroundColor(C.muted)
                        .frame(width: 76).frame(height: 36)
                        .background(C.bg)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 10)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    /// 手动填 deviceId：用于对齐官方 App 已绑定的设备指纹
    private var devRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("deviceId（设备指纹）")
                .font(.system(size: 11))
                .foregroundColor(C.faint)
            Text(api.deviceId)
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(Prefs.s("dev_override").isEmpty ? C.muted : C.green)
                .lineLimit(1).truncationMode(.middle)
            HStack(spacing: 8) {
                TextField("留空用本机 UUID", text: $devInput)
                    .font(.system(size: 11, design: .monospaced))
                    .textFieldStyle(.roundedBorder)
                    .autocapitalization(.allCharacters)
                    .disableAutocorrection(true)
                Button("保存") {
                    let v = devInput.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
                    Prefs.set(v, "dev_override")
                    toast = v.isEmpty ? "已恢复本机 UUID" : "已覆盖"
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { toast = nil }
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .frame(height: 30)
                .background(C.blue)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
        .padding(.vertical, 8)
    }

    /// 手动填 pinToken：填了就走这条路，不再尝试自动换取
    private var pinTokenRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("pinToken（v5 控车凭证）")
                .font(.system(size: 11))
                .foregroundColor(C.faint)
            HStack(spacing: 8) {
                TextField("32 位十六进制，留空则自动获取", text: $pinTokenInput)
                    .font(.system(size: 11, design: .monospaced))
                    .textFieldStyle(.roundedBorder)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                Button("保存") {
                    let v = pinTokenInput.trimmingCharacters(in: .whitespacesAndNewlines)
                    Prefs.set(v, "pin_token")
                    toast = v.isEmpty ? "已清空" : "已保存"
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { toast = nil }
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .frame(height: 30)
                .background(C.blue)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            Text("从抓包里能拿到（v5/control/get-pin-token 的 data）。填一次通常长期有效。")
                .font(.system(size: 9.5))
                .foregroundColor(C.faint)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 8)
    }

    private var traceCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("控车链路日志")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(C.blue)
                Spacer()
                Text("\(trace.isEmpty ? 0 : trace.components(separatedBy: "\n").count) 行")
                    .font(.system(size: 10.5))
                    .foregroundColor(C.faint)
            }
            if trace.isEmpty {
                Text("还没有控车记录。去首页点一次「解锁」或「闪灯」，回来这里就能看到每一步的响应。")
                    .font(.system(size: 12))
                    .foregroundColor(C.muted)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.vertical, 8)
            } else {
                Text(trace)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(C.txt)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func line(_ k: String, _ v: String, _ color: Color) -> some View {
        HStack(alignment: .top) {
            Text(k)
                .font(.system(size: 11.5))
                .foregroundColor(C.faint)
                .frame(width: 82, alignment: .leading)
            Text(v)
                .font(.system(size: 11.5, design: .monospaced))
                .foregroundColor(color)
                .lineLimit(2)
                .truncationMode(.middle)
            Spacer(minLength: 0)
        }
        .frame(minHeight: 30)
    }

    private var sep: some View {
        Rectangle().fill(C.bg).frame(height: 1)
    }

    private var agoText: String {
        let ms = Double(Prefs.l("last_cmd_at"))
        guard ms > 0 else { return "无" }
        let min = Int((Date().timeIntervalSince1970 * 1000 - ms) / 60000)
        if min < 1 { return "刚刚" }
        if min < 60 { return "\(min) 分钟前" }
        return "\(min / 60) 小时前"
    }
}
