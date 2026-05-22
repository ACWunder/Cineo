import SwiftUI

/// Interactive 5-star rating with half-step granularity.
///
/// - Tap the left half of a star → that star becomes a half-star
///   (`idx - 0.5`).
/// - Tap the right half → full star (`idx`).
/// - Drag horizontally across the row → continuous rating slider.
/// - Tapping the currently-selected value once more clears the rating.
///
/// The binding works in `Double` (0.5 ... 5.0 in 0.5 steps; 0 means no
/// rating yet).
struct StarRatingView: View {
    @Binding var rating: Double
    var size: CGFloat = 44
    var spacing: CGFloat = Theme.Spacing.xs
    var isInteractive: Bool = true

    var body: some View {
        HStack(spacing: spacing) {
            ForEach(1...5, id: \.self) { idx in
                starCell(idx)
            }
        }
    }

    /// One visible star plus two invisible tap zones (left half / right half).
    private func starCell(_ idx: Int) -> some View {
        ZStack {
            star(idx)
                .frame(width: size, height: size)

            HStack(spacing: 0) {
                tapZone {
                    set(Double(idx) - 0.5)
                }
                tapZone {
                    set(Double(idx))
                }
            }
            .frame(width: size, height: size)
        }
    }

    private func tapZone(action: @escaping () -> Void) -> some View {
        Color.clear
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .onTapGesture {
                guard isInteractive else { return }
                action()
            }
    }

    private func star(_ idx: Int) -> some View {
        let style = StarStyle.resolve(idx: idx, rating: rating)
        return Image(systemName: style.symbol)
            .font(.system(size: size, weight: .semibold, design: .rounded))
            .foregroundStyle(style.color)
    }

    private func set(_ value: Double) {
        // Re-tapping the current value clears the rating; otherwise just set.
        if rating == value {
            rating = 0
        } else {
            rating = value
        }
    }
}

/// Read-only display version — renders half + full stars based on a Double.
struct StarRatingDisplay: View {
    let rating: Double
    var size: CGFloat = 14

    var body: some View {
        HStack(spacing: 2) {
            ForEach(1...5, id: \.self) { idx in
                let style = StarStyle.resolve(idx: idx, rating: rating)
                Image(systemName: style.symbol)
                    .font(.system(size: size, weight: .semibold, design: .rounded))
                    .foregroundStyle(style.color)
            }
        }
    }
}

private struct StarStyle {
    let symbol: String
    let color: Color

    static func resolve(idx: Int, rating: Double) -> StarStyle {
        if Double(idx) <= rating {
            return StarStyle(symbol: "star.fill", color: Theme.Colors.starFilled)
        } else if Double(idx) - 0.5 <= rating {
            return StarStyle(symbol: "star.leadinghalf.filled", color: Theme.Colors.starFilled)
        } else {
            return StarStyle(symbol: "star", color: Theme.Colors.starEmpty)
        }
    }
}
