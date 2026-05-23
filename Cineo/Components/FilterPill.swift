import SwiftUI

/// Filter pill used in Library / Discover / Watchlist filter strips.
///
/// Callers pass a `minWidth` sized for the pill's widest possible label
/// (e.g. "Bewertung", "Serien", "Genre · 99"). That floor must be at
/// least as large as the natural width of the widest text — otherwise
/// switching to a wider label forces the pill to grow, and the resize
/// gets tweened by whatever animation context happens to be active
/// (Menu dismiss, …), briefly drawing the new wider text inside the
/// old narrower capsule.
///
/// `.fixedSize(horizontal: true)` keeps the Text from being squeezed,
/// and `.clipShape(Capsule())` makes sure anything that does momentarily
/// poke outside the capsule stays inside the rounded silhouette.
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
                .fixedSize(horizontal: true, vertical: false)
            Image(systemName: "chevron.down")
                .font(.system(size: 8, weight: .bold, design: .rounded))
                .opacity(0.7)
        }
        .foregroundStyle(isActive ? Color(hex: 0x2A1A05) : Theme.Colors.accent)
        .padding(.horizontal, Theme.Spacing.sm)
        .padding(.vertical, 6)
        .frame(minWidth: minWidth)
        .background(
            ZStack {
                Capsule().fill(Theme.Colors.backgroundElevated)
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
        .clipShape(Capsule())
        .shadow(
            color: isActive ? Theme.Colors.accentGlow.opacity(0.55) : .clear,
            radius: 10, y: 4
        )
    }
}
