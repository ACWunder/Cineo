import SwiftUI

/// Filter pill used in Library / Discover / Watchlist filter strips.
///
/// The label can change between very different widths (e.g. "Typ" → "Filme")
/// when a value is picked. To avoid the half-frame where the new text is
/// drawn into the *old* capsule and gets clipped at the edges, callers
/// give this view an `.id(...)` that includes the visible text — SwiftUI
/// then rebuilds the pill from scratch on every label change instead of
/// trying to animate the resize. Inside the pill itself nothing animates:
/// `.transaction { $0.animation = nil }` strips any inherited animation,
/// `.fixedSize(horizontal:true)` lets the Text claim its real width, and
/// `.clipShape(Capsule())` guarantees the rounded shape even mid-render.
struct FilterPill: View {
    let icon: String
    let text: String
    let isActive: Bool

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
        .foregroundStyle(isActive ? Color(hex: 0x2A1A05) : Theme.Colors.textPrimary)
        .padding(.horizontal, Theme.Spacing.sm)
        .padding(.vertical, 6)
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
        .clipShape(Capsule())
        .shadow(
            color: isActive ? Theme.Colors.accentGlow.opacity(0.55) : .clear,
            radius: 10, y: 4
        )
        .transaction { $0.animation = nil }
    }
}
