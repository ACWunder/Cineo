import SwiftUI

/// Translucent fullscreen overlay used by Discover and Watchlist for the
/// "mark as watched and rate" flow. Tapping a star saves immediately and
/// dismisses. Skipping saves with no rating but still marks watched.
struct RatingOverlay: View {

    let title: String
    let posterPath: String?
    var onRate: (Int) -> Void        // 1...5
    var onSkip: () -> Void           // mark watched without rating
    var onCancel: () -> Void         // backdrop tap: close without action

    @State private var hoverRating: Int = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            // Translucent backdrop — taps here cancel.
            Color.black.opacity(0.78)
                .ignoresSafeArea()
                .background(.ultraThinMaterial.opacity(0.5))
                .contentShape(Rectangle())
                .onTapGesture { onCancel() }

            VStack(spacing: Theme.Spacing.lg) {
                Spacer(minLength: 0)

                if posterPath != nil {
                    PosterView(path: posterPath, size: "w342", radius: Theme.Radius.md, shadow: true)
                        .frame(width: 140)
                }

                VStack(spacing: Theme.Spacing.xs) {
                    Text("Wie war")
                        .font(Theme.Typography.callout)
                        .foregroundStyle(Theme.Colors.textSecondary)
                    Text(title)
                        .font(Theme.Typography.title2)
                        .foregroundStyle(Theme.Colors.textPrimary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Theme.Spacing.lg)
                }

                stars
                    .padding(.vertical, Theme.Spacing.sm)

                Button(action: onSkip) {
                    Text("Überspringen")
                        .font(Theme.Typography.callout.weight(.semibold))
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .padding(.horizontal, Theme.Spacing.md)
                        .padding(.vertical, Theme.Spacing.xs)
                }
                .buttonStyle(CineoPressStyle())

                Spacer(minLength: 0)
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .transition(.opacity)
        }
        .transition(.opacity)
    }

    private var stars: some View {
        HStack(spacing: Theme.Spacing.sm) {
            ForEach(1...5, id: \.self) { value in
                Button {
                    onRate(value)
                } label: {
                    Image(systemName: value <= hoverRating ? "star.fill" : "star")
                        .font(.system(size: 46, weight: .semibold, design: .rounded))
                        .foregroundStyle(value <= hoverRating ? Theme.Colors.accentLight : Theme.Colors.starEmpty)
                        .frame(width: 56, height: 56)
                        .contentShape(Rectangle())
                }
                .buttonStyle(CineoPressStyle(scale: 0.88))
                .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
                    if pressing { hoverRating = value }
                }, perform: {})
            }
        }
    }
}
