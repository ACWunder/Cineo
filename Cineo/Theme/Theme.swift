import SwiftUI

enum Theme {

    enum Colors {
        static let background = Color(hex: 0x0B0B0F)
        static let surface = Color(hex: 0x16161C)
        static let surfaceElevated = Color(hex: 0x1F1F27)
        static let border = Color(hex: 0x2A2A33)

        static let accent = Color(hex: 0xE8C46A)
        static let accentDim = Color(hex: 0x8A6F32)
        static let danger = Color(hex: 0xE5484D)
        static let success = Color(hex: 0x4ADE80)

        static let textPrimary = Color.white
        static let textSecondary = Color(hex: 0xA1A1AA)
        static let textTertiary = Color(hex: 0x71717A)

        static let starFilled = Color(hex: 0xE8C46A)
        static let starEmpty = Color(hex: 0x3F3F46)

        static let shadow = Color.black.opacity(0.6)
    }

    enum Spacing {
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 8
        static let sm: CGFloat = 12
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
    }

    enum Radius {
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
        static let pill: CGFloat = 999
    }

    enum Typography {
        static let display = Font.system(size: 34, weight: .bold, design: .default)
        static let title = Font.system(size: 28, weight: .bold, design: .default)
        static let title2 = Font.system(size: 22, weight: .semibold, design: .default)
        static let title3 = Font.system(size: 19, weight: .semibold, design: .default)
        static let headline = Font.system(size: 17, weight: .semibold, design: .default)
        static let body = Font.system(size: 16, weight: .regular, design: .default)
        static let callout = Font.system(size: 15, weight: .regular, design: .default)
        static let footnote = Font.system(size: 13, weight: .regular, design: .default)
        static let caption = Font.system(size: 12, weight: .medium, design: .default)
    }

    enum Layout {
        static let buttonHeight: CGFloat = 56
        static let posterAspect: CGFloat = 2.0 / 3.0
        static let cardShadowRadius: CGFloat = 20
    }
}

extension Color {
    init(hex: UInt32, alpha: Double = 1.0) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8) & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }
}

struct CineoBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Theme.Colors.background.ignoresSafeArea())
            .preferredColorScheme(.dark)
    }
}

extension View {
    func cineoBackground() -> some View { modifier(CineoBackground()) }

    func cineoCard(padding: CGFloat = Theme.Spacing.md, radius: CGFloat = Theme.Radius.lg) -> some View {
        self
            .padding(padding)
            .background(Theme.Colors.surface, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(Theme.Colors.border, lineWidth: 0.5)
            )
    }
}
