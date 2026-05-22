import SwiftUI

enum Theme {

    // MARK: - Colors

    enum Colors {
        // Surfaces — deep blue tint, never pure black
        static let background = Color(hex: 0x070A14)
        static let surface = Color(hex: 0x111524)
        static let surfaceElevated = Color(hex: 0x1A2138)
        static let border = Color(hex: 0x232A40)

        // Accent — purple to indigo
        static let accent = Color(hex: 0x8B5CF6)
        static let accentLight = Color(hex: 0xA78BFA)
        static let accentDark = Color(hex: 0x6D28D9)
        static let accentIndigo = Color(hex: 0x6366F1)

        // Diagonal gradient for primary surfaces / highlights
        static let accentGradient = LinearGradient(
            colors: [Color(hex: 0x8B5CF6), Color(hex: 0x6366F1)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        // Slightly softer variant for ambient glow under buttons / cards
        static let accentGlow = Color(hex: 0x8B5CF6).opacity(0.45)

        // Dismissive cue for swipe-overlay (muted, not loud)
        static let dismissTint = Color(hex: 0xE07A5F).opacity(0.85)

        // Texts
        static let textPrimary = Color(hex: 0xF5F6FA)
        static let textSecondary = Color(hex: 0x8A92A6)
        static let textTertiary = Color(hex: 0x5C6479)

        // Stars (lilac, not gold)
        static let starFilled = Color(hex: 0xA78BFA)
        static let starEmpty = Color(hex: 0x232A40)

        // Danger (preserved for "remove" actions, kept calm)
        static let danger = Color(hex: 0xB94A4A)
        static let success = Color(hex: 0x4ADE80)

        static let shadow = Color.black.opacity(0.55)
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
        static let card: CGFloat = 16
        static let lg: CGFloat = 20
        static let xl: CGFloat = 26
        static let pill: CGFloat = 999
    }

    // MARK: - Typography (SF Pro Rounded throughout)

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

        // Note: chose SF Pro Rounded over bundling Sora for build simplicity.
    }

    // MARK: - Layout

    enum Layout {
        static let buttonHeight: CGFloat = 56
        static let primaryButtonRadius: CGFloat = 14
        static let posterAspect: CGFloat = 2.0 / 3.0
        static let cardShadowRadius: CGFloat = 28
        static let circleActionLg: CGFloat = 84
        static let circleActionMd: CGFloat = 64
    }

    // MARK: - Motion

    enum Motion {
        // Snappy but warm. Used for swipe return, card pop, action confirm.
        static let spring: Animation = .spring(response: 0.35, dampingFraction: 0.75)
        // Even punchier for press states and chip ticks.
        static let pop: Animation = .spring(response: 0.25, dampingFraction: 0.8)
        // Softer for screen-level transitions, sheet rises, etc.
        static let soft: Animation = .spring(response: 0.5, dampingFraction: 0.88)
        // For Reduce Motion users: just a gentle fade.
        static let reduced: Animation = .easeOut(duration: 0.2)

        // Helper that returns spring or reduced based on accessibility.
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
            .background(Theme.Colors.background.ignoresSafeArea())
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
                    .strokeBorder(Theme.Colors.border, lineWidth: 0.5)
            )
    }
}

// MARK: - Button press style

/// Scales to ~0.96 on press with a snappy spring. Used by PrimaryButton and CircleActionButton.
struct CineoPressStyle: ButtonStyle {
    var scale: CGFloat = 0.96
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .animation(Theme.Motion.pop, value: configuration.isPressed)
    }
}
