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
            .background(backgroundView)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous)
                    .strokeBorder(borderColor, lineWidth: borderWidth)
            )
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous))
            .shadow(color: glowColor, radius: glowRadius, x: 0, y: 8)
            .contentShape(RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous))
        }
        .buttonStyle(CineoPressStyle())
    }

    @ViewBuilder
    private var backgroundView: some View {
        switch kind {
        case .accent:
            Theme.Colors.accentGradient
        case .neutral:
            Theme.Colors.surface
        case .danger:
            Theme.Colors.danger
        case .ghost:
            Color.clear
        }
    }

    private var foreground: Color {
        switch kind {
        case .accent: Color.black.opacity(0.92)
        case .neutral: Theme.Colors.textPrimary
        case .danger: Theme.Colors.textPrimary
        case .ghost: Theme.Colors.textPrimary
        }
    }
    private var borderColor: Color {
        switch kind {
        case .accent: .clear
        case .neutral: Theme.Colors.border
        case .danger: .clear
        case .ghost: Theme.Colors.border
        }
    }
    private var borderWidth: CGFloat {
        switch kind {
        case .accent, .danger: 0
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
        case .accent, .danger: 18
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
            Image(systemName: symbol)
                .font(.system(size: size * 0.40, weight: .bold, design: .rounded))
                .foregroundStyle(foreground)
                .frame(width: size, height: size)
                .background(backgroundShape)
                .overlay(borderOverlay)
                .shadow(color: glowColor, radius: glowRadius, x: 0, y: 8)
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
                .background(Circle().fill(Theme.Colors.surface.opacity(0.6)))
        case .danger:
            Circle().fill(Theme.Colors.danger.opacity(0.85))
        case .ghost:
            // Translucent: just a faint glass disc, no fill.
            Circle()
                .fill(.ultraThinMaterial.opacity(0.25))
        }
    }

    private var borderOverlay: some View {
        Circle().strokeBorder(borderColor, lineWidth: borderWidth)
    }

    private var foreground: Color {
        switch kind {
        case .accent: Color.black.opacity(0.92)
        case .neutral: Theme.Colors.textPrimary
        case .danger: Theme.Colors.textPrimary
        case .ghost: Theme.Colors.accentLight
        }
    }
    private var borderColor: Color {
        switch kind {
        case .accent: Color.white.opacity(0.18)
        case .neutral, .ghost: Theme.Colors.border
        case .danger: .clear
        }
    }
    private var borderWidth: CGFloat {
        switch kind {
        case .accent: 0.5
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
        case .accent: 22
        case .danger: 18
        default: 10
        }
    }
}
