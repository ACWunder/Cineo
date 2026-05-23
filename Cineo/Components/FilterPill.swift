import SwiftUI

/// Filter pill used in Library / Discover / Watchlist filter strips.
///
/// Callers pass a `minWidth` sized for the pill's widest possible label
/// (e.g. "Bewertung", "Serien", "Genre · 99"). That way the pill never
/// has to grow when the visible label changes — the text just swaps
/// inside a stable capsule, so there's no frame animation that could
/// briefly draw the new text into the old narrower bounds.
struct FilterPill: View {
    let icon: String
    let text: String
    let isActive: Bool
    let minWidth: CGFloat

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
            Text(text)
                .font(Theme.Typography.caption.weight(.semibold))
                .lineLimit(1)
            Image(systemName: "chevron.down")
                .font(.system(size: 8, weight: .bold, design: .rounded))
                .opacity(0.7)
        }
        .foregroundStyle(isActive ? Color(hex: 0x2A1A05) : Theme.Colors.textPrimary)
        .padding(.horizontal, Theme.Spacing.sm)
        .padding(.vertical, 6)
        .frame(minWidth: minWidth)
        .background(
            ZStack {
                Capsule().fill(Theme.Colors.surfaceElevated)
                    .opacity(isActive ? 0 : 1)
                Capsule().fill(Theme.Colors.accentGradient)
                    .opacity(isActive ? 1 : 0)
                Capsule()
                    .fill(Theme.Colors.accentSheen)
                    .blendMode(.plusLighter)
                    .opacity(isActive ? 1 : 0)
                    .allowsHitTesting(false)
            }
        )
        .overlay(
            Capsule().stroke(
                isActive ? Color.white.opacity(0.28) : Theme.Colors.border,
                lineWidth: 0.5
            )
        )
        .shadow(
            color: isActive ? Theme.Colors.accentGlow.opacity(0.55) : .clear,
            radius: 10, y: 4
        )
    }
}
