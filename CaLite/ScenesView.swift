import SwiftUI

/// 组合场景：一次点击执行一串指令
struct CarScene: Identifiable {
    let id = UUID()
    let name: String
    let subtitle: String
    let icon: String
    let tint: Color
    let steps: [(cmd: String, label: String)]
}

struct ScenesView: View {
    @State private var running: String?
    @State private var currentStep = ""
    @State private var done = 0
    @State private var total = 0
    @State private var toast: String?

    private let api = CarAPI.shared

    /// 预设场景（可继续加）
    private var scenes: [CarScene] {
        [
            CarScene(name: "下班模式", subtitle: "启动 · 空调 24°C · 车窗留缝",
                     icon: "figure.walk.departure", tint: Color(hex: 0x2F6FB5),
                     steps: [
                        ("OpenEngine", "启动发动机"),
                        ("WindowSlit", "车窗留缝"),
                        ("openAir", "打开空调")
                     ]),
            CarScene(name: "回家模式", subtitle: "关窗 · 关空调 · 锁车",
                     icon: "house.fill", tint: Color(hex: 0x2F9E68),
                     steps: [
                        ("CloseWindow", "关闭车窗"),
                        ("closeAir", "关闭空调"),
                        ("LockDoor", "锁车")
                     ]),
            CarScene(name: "快速降温", subtitle: "开空调 · 关窗 · 留一条缝",
                     icon: "snowflake", tint: Color(hex: 0x1E88A8),
                     steps: [
                        ("CloseWindow", "关闭车窗"),
                        ("WindowSlit", "车窗留缝"),
                        ("openAir", "打开空调")
                     ]),
            CarScene(name: "离车检查", subtitle: "关窗 · 熄火 · 锁车",
                     icon: "checkmark.shield.fill", tint: Color(hex: 0x8A6D3B),
                     steps: [
                        ("CloseWindow", "关闭车窗"),
                        ("CloseEngine", "熄火"),
                        ("LockDoor", "锁车")
                     ])
        ]
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                if running != nil {
                    progressCard
                }
                ForEach(scenes) { s in
                    sceneCard(s)
                }
                Text("场景按顺序逐条下发，每条间隔 1.2 秒。\n指令未完成时后续指令会被车端拒绝。")
                    .font(.system(size: 10))
                    .foregroundColor(C.faint)
                    .multilineTextAlignment(.center)
                    .padding(.top, 6)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 14)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .background(C.bg.ignoresSafeArea())
        .navigationTitle("组合场景")
        .navigationBarTitleDisplayMode(.inline)
        .overlay(alignment: .bottom) {
            if let t = toast {
                Text(t)
                    .font(.system(size: 13))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .background(C.txt.opacity(0.9))
                    .clipShape(Capsule())
                    .padding(.bottom, 30)
            }
        }
    }

    private func sceneCard(_ s: CarScene) -> some View {
        Button {
            run(s)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: s.icon)
                    .font(.system(size: 20))
                    .foregroundColor(.white)
                    .frame(width: 42, height: 42)
                    .background(s.tint)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text(s.name)
                        .font(.system(size: 14.5, weight: .semibold))
                        .foregroundColor(C.txt)
                    Text(s.subtitle)
                        .font(.system(size: 11))
                        .foregroundColor(C.muted)
                        .lineLimit(1)
                }
                Spacer(minLength: 4)
                if running == s.name {
                    ProgressView().scaleEffect(0.8)
                } else {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(s.tint.opacity(running == nil ? 1 : 0.3))
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(running != nil)
    }

    private var progressCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(running ?? "")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(C.blue)
                Spacer()
                Text("\(done)/\(total)")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(C.muted)
            }
            ProgressView(value: total > 0 ? Double(done) / Double(total) : 0)
            Text(currentStep)
                .font(.system(size: 11.5))
                .foregroundColor(C.muted)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(C.blue.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: 执行

    private func run(_ scene: CarScene) {
        guard !api.controlPin.isEmpty else {
            toast = "请先设置控车码"
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { toast = nil }
            return
        }
        running = scene.name
        total = scene.steps.count
        done = 0
        var index = 0

        func next() {
            if index >= scene.steps.count {
                running = nil
                toast = "\(scene.name) 执行完成"
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) { toast = nil }
                return
            }
            let step = scene.steps[index]
            currentStep = step.label
            index += 1
            api.control(cmd: step.cmd) { ok, msg in
                OpLogStore.append(cmd: "\(scene.name)·\(step.label)", ok: ok, msg: msg)
                DispatchQueue.main.async {
                    done = index
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { next() }
                }
            }
        }
        next()
    }
}
