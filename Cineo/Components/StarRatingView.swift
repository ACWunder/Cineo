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

    private var totalWidth: CGFloat { 5 * size + 4 * spacing }

    var body: some View {
        HStack(spacing: spacing) {
            ForEach(1...5, id: \.self) { idx in
                star(idx)
                    .frame(width: size, height: size)
            }
        }
        .frame(width: totalWidth, height: size)
        .contentShape(Rectangle())
        .gesture(isInteractive ? slideGesture : nil)
    }

    private func star(_ idx: Int) -> some View {
        let style = StarStyle.resolve(idx: idx, rating: rating)
        return Image(systemName: style.symbol)
            .font(.system(size: size, weight: .semibold, design: .rounded))
            .foregroundStyle(style.color)
    }

    private var slideGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in apply(value.location.x, dragged: true) }
            .onEnded   { value in apply(value.location.x, dragged: false) }
    }

    /// Maps the horizontal touch coordinate to a 0.5-stepped rating.
    /// During a drag we never toggle (clear) — only taps with no movement
    /// can clear back to 0 by re-selecting the current value.
    private func apply(_ x: CGFloat, dragged: Bool) {
        let stride = size + spacing
        let clamped = max(0, x)

        for idx in 1...5 {
            let starStart = CGFloat(idx - 1) * stride
            let starMid = starStart + size / 2
            let starEnd = starStart + size

            if clamped <= starMid {
                set(Double(idx) - 0.5, dragged: dragged); return
            }
            if clamped <= starEnd + spacing / 2 {
                set(Double(idx), dragged: dragged); return
            }
        }
        set(5, dragged: dragged)
    }

    private func set(_ value: Double, dragged: Bool) {
        if !dragged && rating == value {
            rating = 0
        } else if rating != value {
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
