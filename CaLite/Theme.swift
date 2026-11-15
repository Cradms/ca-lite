import SwiftUI

// MARK: - 主题色
enum C {
    static let bg     = Color(red: 243/255, green: 246/255, blue: 250/255)
    static let card   = Color.white
    static let border = Color(red: 230/255, green: 235/255, blue: 241/255)
    static let blue   = Color(red: 47/255, green: 111/255, blue: 181/255)
    static let green  = Color(red: 47/255, green: 158/255, blue: 104/255)
    static let red    = Color(red: 214/255, green: 69/255, blue: 69/255)
    static let amber  = Color(red: 217/255, green: 131/255, blue: 36/255)
    static let txt    = Color(red: 26/255, green: 30/255, blue: 36/255)
    static let muted  = Color(red: 123/255, green: 133/255, blue: 146/255)
    static let faint  = Color(red: 152/255, green: 162/255, blue: 175/255)
}

/// Android 源码「长安车控」首页用的原始色值（1:1 复刻用）
enum KH {
    static let blue  = Color(red: 0x2F/255, green: 0x6F/255, blue: 0xB5/255)  // 0xFF2F6FB5
    static let bg    = Color(red: 0xF3/255, green: 0xF6/255, blue: 0xFA/255)  // 0xFFF3F6FA
    static let text  = Color(red: 0x1A/255, green: 0x1E/255, blue: 0x24/255)  // 0xFF1A1E24
    static let grey  = Color(red: 0x6B/255, green: 0x74/255, blue: 0x82/255)  // 0xFF6B7482
    static let red   = Color(red: 0xE5/255, green: 0x39/255, blue: 0x35/255)  // 0xFFE53935
}

extension Color {
    /// 0xRRGGBB / 0xAARRGGBB
    init(hex: UInt32) {
        let a = Double((hex >> 24) & 0xFF) / 255
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >> 8) & 0xFF) / 255
        let b = Double(hex & 0xFF) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: hex > 0xFFFFFF ? a : 1)
    }
}

// MARK: - 卡片容器
struct Card<Content: View>: View {
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }
    var body: some View {
        content
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(C.card)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(C.border, lineWidth: 1))
    }
}
