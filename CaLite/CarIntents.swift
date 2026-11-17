import AppIntents
import Foundation

// MARK: - Siri / 快捷指令入口
//
// 没有小组件时，AppIntents 是最好的替代：
//   - 快捷指令 App 里可以直接搜到这些动作
//   - 「嘿 Siri，用 CA Lite 解锁车辆」
//   - 可以挂到锁屏、自动化（如连接车载蓝牙自动开空调）、轻点背面

private enum IntentSupport {
    static func ready() -> Bool { CarAPI.shared.isLoggedIn }

    static func run(_ cmd: String, _ name: String) async -> some IntentResult & ProvidesDialog {
        guard ready() else {
            return .result(dialog: "还没登录 CA Lite，先打开 App 完成登录")
        }
        let ok = await CarAPI.shared.controlAsync(cmd)
        return .result(dialog: ok ? "\(name)指令已发送" : "\(name)发送失败，稍后重试")
    }
}

// MARK: - 解锁 / 上锁

struct UnlockCarIntent: AppIntent {
    static var title: LocalizedStringResource = "解锁车辆"
    static var description = IntentDescription("通过 CA Lite 解锁车门")
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        await IntentSupport.run("UnLockDoor", "解锁")
    }
}

struct LockCarIntent: AppIntent {
    static var title: LocalizedStringResource = "上锁车辆"
    static var description = IntentDescription("通过 CA Lite 锁车")
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        await IntentSupport.run("LockDoor", "上锁")
    }
}

// MARK: - 空调

struct OpenAirIntent: AppIntent {
    static var title: LocalizedStringResource = "打开空调"
    static var description = IntentDescription("通过 CA Lite 打开车内空调")
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        await IntentSupport.run("openAir", "打开空调")
    }
}

struct CloseAirIntent: AppIntent {
    static var title: LocalizedStringResource = "关闭空调"
    static var description = IntentDescription("通过 CA Lite 关闭车内空调")
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        await IntentSupport.run("closeAir", "关闭空调")
    }
}

// MARK: - 闪灯寻车

struct FlashCarIntent: AppIntent {
    static var title: LocalizedStringResource = "闪灯寻车"
    static var description = IntentDescription("让车辆闪灯，方便在停车场找车")
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        await IntentSupport.run("FlashLight", "闪灯")
    }
}

// MARK: - 查询续航

struct CarRangeIntent: AppIntent {
    static var title: LocalizedStringResource = "查询剩余续航"
    static var description = IntentDescription("读取车辆剩余续航里程")
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard IntentSupport.ready() else {
            return .result(dialog: "还没登录 CA Lite，先打开 App 完成登录")
        }
        guard let d = await CarAPI.shared.carDataAsync() else {
            return .result(dialog: "没取到车况，车机可能离线")
        }
        let range = (d["range"] as? Int) ?? 0
        let name = (d["carName"] as? String) ?? "你的车"
        if range <= 0 {
            return .result(dialog: "\(name) 暂时没有续航数据")
        }
        return .result(dialog: "\(name) 剩余续航 \(range) 公里")
    }
}

// MARK: - 注册到系统

struct CaLiteShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: UnlockCarIntent(),
            phrases: [
                "用 \(.applicationName) 解锁车辆",
                "\(.applicationName) 解锁"
            ],
            shortTitle: "解锁车辆",
            systemImageName: "lock.open.fill"
        )
        AppShortcut(
            intent: LockCarIntent(),
            phrases: [
                "用 \(.applicationName) 锁车",
                "\(.applicationName) 上锁"
            ],
            shortTitle: "上锁车辆",
            systemImageName: "lock.fill"
        )
        AppShortcut(
            intent: OpenAirIntent(),
            phrases: [
                "用 \(.applicationName) 打开空调",
                "\(.applicationName) 开空调"
            ],
            shortTitle: "打开空调",
            systemImageName: "snowflake"
        )
        AppShortcut(
            intent: CloseAirIntent(),
            phrases: [
                "用 \(.applicationName) 关闭空调",
                "\(.applicationName) 关空调"
            ],
            shortTitle: "关闭空调",
            systemImageName: "wind"
        )
        AppShortcut(
            intent: FlashCarIntent(),
            phrases: [
                "用 \(.applicationName) 闪灯寻车",
                "\(.applicationName) 找车"
            ],
            shortTitle: "闪灯寻车",
            systemImageName: "lightbulb"
        )
        AppShortcut(
            intent: CarRangeIntent(),
            phrases: [
                "用 \(.applicationName) 查续航",
                "\(.applicationName) 还能跑多远"
            ],
            shortTitle: "查询续航",
            systemImageName: "fuelpump"
        )
    }
}
