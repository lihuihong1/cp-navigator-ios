import SwiftUI

/// 与 Android 版对齐的配色与卡片样式（Ui.java 的调色板）。
enum Theme {
    static let bg = Color(hex: 0xF3F4F6)
    static let card = Color.white
    static let text = Color(hex: 0x15181C)
    static let sub = Color(hex: 0x6B7280)
    static let line = Color(hex: 0xE5E7EB)
    static let accent = Color(hex: 0x2563EB)
    static let red = Color(hex: 0xDC2626)
    static let green = Color(hex: 0x16A34A)
    static let star = Color(hex: 0xF59E0B)
    static let starOff = Color(hex: 0x9AA1AC)
    static let warn = Color(hex: 0xB45309)
}

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}

private struct CardStyle: ViewModifier {
    var padding: CGFloat

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(Theme.card)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

extension View {
    /// 白色圆角卡片（Android Ui.card）。
    func card(padding: CGFloat = 0) -> some View {
        modifier(CardStyle(padding: padding))
    }

    func card() -> some View {
        modifier(CardStyle(padding: 0))
    }
}

/// 细分割线。
struct Line: View {
    var inset: CGFloat = 0

    var body: some View {
        Rectangle()
            .fill(Theme.line)
            .frame(height: 0.6)
            .padding(.leading, inset)
    }
}