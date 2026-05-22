import SwiftUI

struct PrimaryButton: View {

    enum Kind {
        case accent
        case neutral
        case danger
        case ghost
    }

    let title: String
    var symbol: String?
    var kind: Kind = .accent
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Spacing.xs) {
                if let symbol {
                    Image(systemName: symbol)
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                }
                Text(title)
                    .font(Theme.Typography.headline)
            }
            .frame(maxWidth: .infinity, minHeight: Theme.Layout.buttonHeight)
            .padding(.horizontal, Theme.Spacing.md)
            .foregroundStyle(foreground)
            .background(backgroundLayer)
            .overlay(borderOverlay)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous))
            .shadow(color: glowColor, radius: glowRadius, x: 0, y: 8)
            .contentShape(RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous))
        }
        .buttonStyle(CineoPressStyle())
    }

    @ViewBuilder
    private var backgroundLayer: some View {
        switch kind {
        case .accent:
            ZStack {
                RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous)
                    .fill(Theme.Colors.accentGradient)
                RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous)
                    .fill(Theme.Colors.accentSheen)
                    .blendMode(.plusLighter)
                    .allowsHitTesting(false)
            }
        case .neutral:
            RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous)
                .fill(Theme.Colors.surface)
        case .danger:
            RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous)
                .fill(Theme.Colors.danger)
        case .ghost:
            Color.clear
        }
    }

    private var borderOverlay: some View {
        RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous)
            .strokeBorder(borderColor, lineWidth: borderWidth)
    }

    private var foreground: Color {
        switch kind {
        case .accent: Color(hex: 0x2A1A05)
        case .neutral: Theme.Colors.textPrimary
        case .danger: Theme.Colors.textPrimary
        case .ghost: Theme.Colors.textPrimary
        }
    }
    private var borderColor: Color {
        switch kind {
        case .accent: Color.white.opacity(0.22)
        case .neutral: Theme.Colors.border
        case .danger: .clear
        case .ghost: Theme.Colors.border
        }
    }
    private var borderWidth: CGFloat {
        switch kind {
        case .accent: 0.6
        case .danger: 0
        case .neutral, .ghost: 1
        }
    }
    private var glowColor: Color {
        switch kind {
        case .accent: Theme.Colors.accentGlow
        case .danger: Theme.Colors.danger.opacity(0.32)
        default: .clear
        }
    }
    private var glowRadius: CGFloat {
        switch kind {
        case .accent, .danger: 22
        default: 0
        }
    }
}

struct CircleActionButton: View {
    let symbol: String
    let kind: PrimaryButton.Kind
    var size: CGFloat = Theme.Layout.circleActionMd
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                backgroundShape
                sheenLayer
                Image(systemName: symbol)
                    .font(.system(size: size * 0.42, weight: .bold, design: .rounded))
                    .foregroundStyle(foreground)
            }
            .frame(width: size, height: size)
            .overlay(borderOverlay)
            .shadow(color: glowColor, radius: glowRadius, x: 0, y: 10)
        }
        .buttonStyle(CineoPressStyle(scale: 0.92))
    }

    @ViewBuilder
    private var backgroundShape: some View {
        switch kind {
        case .accent:
            Circle().fill(Theme.Colors.accentGradient)
        case .neutral:
            Circle()
                .fill(.ultraThinMaterial)
                .background(Circle().fill(Theme.Colors.surface.opacity(0.55)))
        case .danger:
            Circle().fill(Theme.Colors.danger.opacity(0.85))
        case .ghost:
            Circle()
                .fill(.ultraThinMaterial.opacity(0.22))
        }
    }

    /// Specular highlight at the top-left, only for fills that should look glossy.
    @ViewBuilder
    private var sheenLayer: some View {
        switch kind {
        case .accent:
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.white.opacity(0.55), Color.clear],
                        center: .init(x: 0.3, y: 0.22),
                        startRadius: 1,
                        endRadius: size * 0.55
                    )
                )
                .blendMode(.plusLighter)
                .allowsHitTesting(false)
        case .neutral:
            Circle()
                .strokeBorder(Color.white.opacity(0.06), lineWidth: 0.5)
                .padding(2)
                .allowsHitTesting(false)
        default:
            EmptyView()
        }
    }

    private var borderOverlay: some View {
        Circle().strokeBorder(borderColor, lineWidth: borderWidth)
    }

    private var foreground: Color {
        switch kind {
        case .accent: Color(hex: 0x2A1A05)
        case .neutral: Theme.Colors.textPrimary
        case .danger: Theme.Colors.textPrimary
        case .ghost: Theme.Colors.accentLight
        }
    }
    private var borderColor: Color {
        switch kind {
        case .accent: Color.white.opacity(0.28)
        case .neutral, .ghost: Theme.Colors.border
        case .danger: .clear
        }
    }
    private var borderWidth: CGFloat {
        switch kind {
        case .accent: 0.6
        case .neutral, .ghost: 1
        case .danger: 0
        }
    }
    private var glowColor: Color {
        switch kind {
        case .accent: Theme.Colors.accentGlow
        case .danger: Theme.Colors.danger.opacity(0.4)
        default: Theme.Colors.shadowSoft
        }
    }
    private var glowRadius: CGFloat {
        switch kind {
        case .accent: 26
        case .danger: 18
        default: 10
        }
    }
}
