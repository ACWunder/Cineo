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
                        .font(.system(size: 18, weight: .semibold))
                }
                Text(title)
                    .font(Theme.Typography.headline)
            }
            .frame(maxWidth: .infinity, minHeight: Theme.Layout.buttonHeight)
            .padding(.horizontal, Theme.Spacing.md)
            .foregroundStyle(foreground)
            .background(background, in: RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                    .strokeBorder(border, lineWidth: borderWidth)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var foreground: Color {
        switch kind {
        case .accent: Theme.Colors.background
        case .neutral: Theme.Colors.textPrimary
        case .danger: Theme.Colors.textPrimary
        case .ghost: Theme.Colors.textPrimary
        }
    }
    private var background: Color {
        switch kind {
        case .accent: Theme.Colors.accent
        case .neutral: Theme.Colors.surface
        case .danger: Theme.Colors.danger
        case .ghost: Color.clear
        }
    }
    private var border: Color {
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
}

struct CircleActionButton: View {
    let symbol: String
    let kind: PrimaryButton.Kind
    var size: CGFloat = 72
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size * 0.42, weight: .bold))
                .foregroundStyle(foreground)
                .frame(width: size, height: size)
                .background(background, in: Circle())
                .overlay(Circle().strokeBorder(border, lineWidth: 1))
                .shadow(color: Theme.Colors.shadow.opacity(0.5), radius: 8, y: 4)
        }
        .buttonStyle(.plain)
    }

    private var foreground: Color {
        switch kind {
        case .accent: Theme.Colors.background
        case .neutral: Theme.Colors.textPrimary
        case .danger: Theme.Colors.textPrimary
        case .ghost: Theme.Colors.textPrimary
        }
    }
    private var background: Color {
        switch kind {
        case .accent: Theme.Colors.accent
        case .neutral: Theme.Colors.surface
        case .danger: Theme.Colors.danger
        case .ghost: Theme.Colors.surface
        }
    }
    private var border: Color {
        switch kind {
        case .accent: .clear
        case .neutral, .ghost: Theme.Colors.border
        case .danger: .clear
        }
    }
}
