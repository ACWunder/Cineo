import SwiftUI

struct DiscoverCardView: View {
    let candidate: DiscoverViewModel.Candidate

    var body: some View {
        GeometryReader { geo in
            let cardWidth = geo.size.width
            let posterHeight = cardWidth / Theme.Layout.posterAspect

            ZStack(alignment: .bottom) {
                // Cover dominates the card
                PosterView(
                    path: candidate.posterPath,
                    size: "w780",
                    radius: 0,
                    shadow: false
                )
                .frame(width: cardWidth, height: posterHeight)
                .clipped()

                // Top edge vignette — Netflix-style darken at the top
                LinearGradient(
                    colors: [Color.black.opacity(0.45), .clear],
                    startPoint: .top,
                    endPoint: .center
                )
                .frame(height: 160)
                .frame(maxHeight: .infinity, alignment: .top)
                .allowsHitTesting(false)

                // Bottom scrim — strong enough that meta + overview stay legible
                LinearGradient(
                    colors: [
                        Color.black.opacity(0),
                        Color.black.opacity(0.6),
                        Color.black.opacity(0.95)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 280)
                .frame(maxWidth: .infinity, alignment: .bottom)
                .allowsHitTesting(false)

                // Meta block sits over the poster bottom for a cinematic feel
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    if !candidate.genres.isEmpty {
                        Text(candidate.genres.prefix(3).joined(separator: "  ·  ").uppercased())
                            .font(Theme.Typography.caption)
                            .tracking(1.4)
                            .foregroundStyle(Theme.Colors.accent)
                    }
                    Text(candidate.title)
                        .font(Theme.Typography.title)
                        .foregroundStyle(Theme.Colors.textPrimary)
                        .shadow(color: .black.opacity(0.5), radius: 8, x: 0, y: 2)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                    metaRow
                        .padding(.top, 2)
                    if !candidate.overview.isEmpty {
                        Text(candidate.overview)
                            .font(Theme.Typography.callout)
                            .foregroundStyle(Theme.Colors.textPrimary.opacity(0.86))
                            .lineLimit(3)
                            .padding(.top, 2)
                    }
                }
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.bottom, Theme.Spacing.lg)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .aspectRatio(0.66, contentMode: .fit)
        .background(Theme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.xl, style: .continuous))
        .overlay(
            // Subtle gold rim — Apple-style hairline
            RoundedRectangle(cornerRadius: Theme.Radius.xl, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            Theme.Colors.accent.opacity(0.45),
                            Theme.Colors.accent.opacity(0.08),
                            .clear
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 0.7
                )
        )
        .shadow(color: Theme.Colors.shadow, radius: 40, x: 0, y: 26)
        .shadow(color: Theme.Colors.accentGlow.opacity(0.15), radius: 60, x: 0, y: 0)
    }

    private var metaRow: some View {
        HStack(spacing: 6) {
            metaChip {
                Label(candidate.mediaType.displayName, systemImage: candidate.mediaType.symbol)
            }
            if !candidate.year.isEmpty {
                metaChip { Text(candidate.year) }
            }
            if candidate.voteAverage > 0 {
                metaChip {
                    HStack(spacing: 3) {
                        Image(systemName: "star.fill")
                            .foregroundStyle(Theme.Colors.starFilled)
                        Text(String(format: "%.1f", candidate.voteAverage))
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func metaChip<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .font(Theme.Typography.caption)
            .foregroundStyle(Theme.Colors.textPrimary.opacity(0.92))
            .padding(.horizontal, Theme.Spacing.xs)
            .padding(.vertical, 5)
            .background(.ultraThinMaterial.opacity(0.55), in: Capsule())
            .overlay(Capsule().strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5))
    }
}
