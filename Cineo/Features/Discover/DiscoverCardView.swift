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

                // Top edge vignette
                LinearGradient(
                    colors: [Color.black.opacity(0.5), .clear],
                    startPoint: .top,
                    endPoint: .center
                )
                .frame(height: 160)
                .frame(maxHeight: .infinity, alignment: .top)
                .allowsHitTesting(false)

                // Glossy diagonal sheen — premium "lit" feel
                LinearGradient(
                    stops: [
                        .init(color: Color.white.opacity(0.22), location: 0.0),
                        .init(color: Color.white.opacity(0.05), location: 0.35),
                        .init(color: Color.clear, location: 0.6)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .blendMode(.plusLighter)
                .allowsHitTesting(false)

                // Bottom scrim — strong enough that meta + overview stay legible
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0.0),
                        .init(color: Color.black.opacity(0.65), location: 0.6),
                        .init(color: Color.black.opacity(0.96), location: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 300)
                .frame(maxWidth: .infinity, alignment: .bottom)
                .allowsHitTesting(false)

                // Meta block sits over the poster bottom
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    if !candidate.genres.isEmpty {
                        Text(candidate.genres.prefix(3).joined(separator: " · ").uppercased())
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .tracking(1.2)
                            .foregroundStyle(Theme.Colors.accentLight.opacity(0.85))
                            .lineLimit(1)
                            .shadow(color: Theme.Colors.accentGlow.opacity(0.3), radius: 4, y: 1)
                    }
                    Text(candidate.title)
                        .font(Theme.Typography.title)
                        .foregroundStyle(Theme.Colors.textPrimary)
                        .shadow(color: .black.opacity(0.55), radius: 10, x: 0, y: 3)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                    metaRow
                        .padding(.top, 2)
                    if !candidate.overview.isEmpty {
                        Text(candidate.overview)
                            .font(Theme.Typography.callout)
                            .foregroundStyle(Theme.Colors.textPrimary.opacity(0.88))
                            .lineLimit(3)
                            .padding(.top, 2)
                    }
                }
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.bottom, Theme.Spacing.lg)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .aspectRatio(0.62, contentMode: .fit)
        .background(Theme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.xl, style: .continuous))
        .overlay(
            // Brighter gold hairline rim that fades down
            RoundedRectangle(cornerRadius: Theme.Radius.xl, style: .continuous)
                .stroke(
                    LinearGradient(
                        stops: [
                            .init(color: Theme.Colors.accentLight.opacity(0.75), location: 0.0),
                            .init(color: Theme.Colors.accent.opacity(0.35), location: 0.4),
                            .init(color: .clear, location: 1.0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 0.9
                )
        )
        .shadow(color: Theme.Colors.shadow, radius: 44, x: 0, y: 28)
        .shadow(color: Theme.Colors.accentGlow.opacity(0.22), radius: 70, x: 0, y: 0)
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
            .foregroundStyle(Theme.Colors.textPrimary.opacity(0.94))
            .padding(.horizontal, Theme.Spacing.xs)
            .padding(.vertical, 5)
            .background(.ultraThinMaterial.opacity(0.6), in: Capsule())
            .overlay(
                Capsule().stroke(
                    LinearGradient(
                        colors: [Color.white.opacity(0.18), Color.white.opacity(0.04)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 0.5
                )
            )
    }
}
