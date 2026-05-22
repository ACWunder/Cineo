import SwiftUI

enum Theme {

    // MARK: - Colors

    enum Colors {
        // Backgrounds — near-black anthracite with a hint of warmth (Netflix-ish).
        static let background = Color(hex: 0x07080C)
        static let backgroundElevated = Color(hex: 0x0E0F14)
        static let surface = Color(hex: 0x14151B)
        static let surfaceElevated = Color(hex: 0x1C1D26)
        static let border = Color(hex: 0x2A2B36)
        static let borderSubtle = Color(hex: 0x1F2029)

        // Accent — cinema gold
        static let accent = Color(hex: 0xE8C46A)
        static let accentLight = Color(hex: 0xF4D88F)
        static let accentDark = Color(hex: 0xB8932F)

        // Diagonal gold gradient for primary fills + highlights
        static let accentGradient = LinearGradient(
            colors: [Color(hex: 0xF4D88F), Color(hex: 0xC9A14A)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        // Soft gold halo used around hero cards / primary buttons
        static let accentGlow = Color(hex: 0xE8C46A).opacity(0.32)

        // Background radial — subtle warm spotlight from top
        static let backgroundGlow = RadialGradient(
            colors: [Color(hex: 0x1A1410).opacity(0.85), Color(hex: 0x07080C)],
            center: .init(x: 0.5, y: -0.1),
            startRadius: 40,
            endRadius: 600
        )

        // Dismiss tint (left swipe) — muted ember red, not loud
        static let dismissTint = Color(hex: 0xCE6B5A)

        // Texts
        static let textPrimary = Color(hex: 0xF6F1E4)
        static let textSecondary = Color(hex: 0x96978F)
        static let textTertiary = Color(hex: 0x5E5F58)

        // Stars (gold)
        static let starFilled = Color(hex: 0xE8C46A)
        static let starEmpty = Color(hex: 0x2A2B36)

        // Danger
        static let danger = Color(hex: 0xB94A4A)
        static let success = Color(hex: 0x4ADE80)

        static let shadow = Color.black.opacity(0.7)
        static let shadowSoft = Color.black.opacity(0.35)
    }

    // MARK: - Spacing

    enum Spacing {
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 8
        static let sm: CGFloat = 12
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
    }

    // MARK: - Radius

    enum Radius {
        static let sm: CGFloat = 10
        static let button: CGFloat = 14
        static let md: CGFloat = 16
        static let card: CGFloat = 18
        static let lg: CGFloat = 22
        static let xl: CGFloat = 28
        static let pill: CGFloat = 999
    }

    // MARK: - Typography (SF Pro Rounded)

    enum Typography {
        static let display = Font.system(size: 36, weight: .bold, design: .rounded)
        static let title = Font.system(size: 28, weight: .bold, design: .rounded)
        static let title2 = Font.system(size: 22, weight: .semibold, design: .rounded)
        static let title3 = Font.system(size: 19, weight: .semibold, design: .rounded)
        static let headline = Font.system(size: 17, weight: .semibold, design: .rounded)
        static let body = Font.system(size: 16, weight: .regular, design: .rounded)
        static let callout = Font.system(size: 15, weight: .regular, design: .rounded)
        static let footnote = Font.system(size: 13, weight: .regular, design: .rounded)
        static let caption = Font.system(size: 12, weight: .medium, design: .rounded)
        static let label = Font.system(size: 14, weight: .semibold, design: .rounded)
    }

    // MARK: - Layout

    enum Layout {
        static let buttonHeight: CGFloat = 56
        static let primaryButtonRadius: CGFloat = 14
        static let posterAspect: CGFloat = 2.0 / 3.0
        static let cardShadowRadius: CGFloat = 30
        static let circleActionLg: CGFloat = 64
        static let circleActionMd: CGFloat = 56
        static let circleActionSm: CGFloat = 48
    }

    // MARK: - Motion

    enum Motion {
        static let spring: Animation = .spring(response: 0.35, dampingFraction: 0.75)
        static let pop: Animation = .spring(response: 0.25, dampingFraction: 0.8)
        static let soft: Animation = .spring(response: 0.5, dampingFraction: 0.88)
        static let reduced: Animation = .easeOut(duration: 0.2)

        static func adaptive(reduce: Bool) -> Animation {
            reduce ? reduced : spring
        }
    }
}

// MARK: - Hex helper

extension Color {
    init(hex: UInt32, alpha: Double = 1.0) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8) & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }
}

// MARK: - View modifiers

struct CineoBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    Theme.Colors.background
                    Theme.Colors.backgroundGlow
                        .opacity(0.7)
                        .blendMode(.plusLighter)
                }
                .ignoresSafeArea()
            )
            .preferredColorScheme(.dark)
    }
}

extension View {
    func cineoBackground() -> some View { modifier(CineoBackground()) }

    /// Surface card style — depth through brightness, not heavy shadows.
    func cineoCard(padding: CGFloat = Theme.Spacing.md,
                   radius: CGFloat = Theme.Radius.card,
                   elevated: Bool = false) -> some View {
        self
            .padding(padding)
            .background(
                (elevated ? Theme.Colors.surfaceElevated : Theme.Colors.surface),
                in: RoundedRectangle(cornerRadius: radius, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(Theme.Colors.borderSubtle, lineWidth: 0.5)
            )
    }
}

// MARK: - Button press style

/// Scales to ~0.96 on press with a snappy spring.
struct CineoPressStyle: ButtonStyle {
    var scale: CGFloat = 0.96
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .animation(Theme.Motion.pop, value: configuration.isPressed)
    }
}
