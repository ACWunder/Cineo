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

                // Gradient overlay so text below stays legible if it bleeds onto the poster
                LinearGradient(
                    colors: [Color.black.opacity(0), Color.black.opacity(0.45), Color.black.opacity(0.92)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 220)
                .frame(maxWidth: .infinity, alignment: .bottom)

                // Meta block sits over the poster bottom for a cinematic feel
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    if !candidate.genres.isEmpty {
                        Text(candidate.genres.prefix(3).joined(separator: " · ").uppercased())
                            .font(Theme.Typography.caption)
                            .tracking(1.1)
                            .foregroundStyle(Theme.Colors.accentLight)
                    }
                    Text(candidate.title)
                        .font(Theme.Typography.title)
                        .foregroundStyle(Theme.Colors.textPrimary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                    metaRow
                    if !candidate.overview.isEmpty {
                        Text(candidate.overview)
                            .font(Theme.Typography.callout)
                            .foregroundStyle(Theme.Colors.textPrimary.opacity(0.85))
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
            RoundedRectangle(cornerRadius: Theme.Radius.xl, style: .continuous)
                .strokeBorder(Theme.Colors.border, lineWidth: 0.5)
        )
        .shadow(color: Theme.Colors.shadow, radius: 34, x: 0, y: 22)
    }

    private var metaRow: some View {
        HStack(spacing: Theme.Spacing.xs) {
            Label(candidate.mediaType.displayName, systemImage: candidate.mediaType.symbol)
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Colors.textPrimary.opacity(0.9))
                .padding(.horizontal, Theme.Spacing.xs)
                .padding(.vertical, 5)
                .background(.ultraThinMaterial, in: Capsule())
            if !candidate.year.isEmpty {
                Text(candidate.year)
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.textPrimary.opacity(0.9))
                    .padding(.horizontal, Theme.Spacing.xs)
                    .padding(.vertical, 5)
                    .background(.ultraThinMaterial, in: Capsule())
            }
            if candidate.voteAverage > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .foregroundStyle(Theme.Colors.accentLight)
                    Text(String(format: "%.1f", candidate.voteAverage))
                        .foregroundStyle(Theme.Colors.textPrimary.opacity(0.95))
                }
                .font(Theme.Typography.caption)
                .padding(.horizontal, Theme.Spacing.xs)
                .padding(.vertical, 5)
                .background(.ultraThinMaterial, in: Capsule())
            }
        }
    }
}
