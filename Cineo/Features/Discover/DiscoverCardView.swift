import SwiftUI

struct DiscoverCardView: View {
    let candidate: DiscoverViewModel.Candidate

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            PosterView(path: candidate.posterPath, size: "w500", radius: Theme.Radius.lg)
                .frame(maxWidth: .infinity)

            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(candidate.title)
                    .font(Theme.Typography.title2)
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .lineLimit(2)
                metaRow
                if !candidate.genres.isEmpty {
                    Text(candidate.genres.prefix(3).joined(separator: " · "))
                        .font(Theme.Typography.footnote)
                        .foregroundStyle(Theme.Colors.accent)
                }
                if !candidate.overview.isEmpty {
                    Text(candidate.overview)
                        .font(Theme.Typography.callout)
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .lineLimit(5)
                        .padding(.top, 2)
                }
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.bottom, Theme.Spacing.md)
        }
        .background(Theme.Colors.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.xl, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.xl, style: .continuous)
                .strokeBorder(Theme.Colors.border, lineWidth: 0.5)
        )
        .shadow(color: Theme.Colors.shadow, radius: 30, y: 16)
    }

    private var metaRow: some View {
        HStack(spacing: Theme.Spacing.xs) {
            Label(candidate.mediaType.displayName, systemImage: candidate.mediaType.symbol)
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Colors.textSecondary)
            if !candidate.year.isEmpty {
                Text("·").foregroundStyle(Theme.Colors.textTertiary)
                Text(candidate.year)
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
            if candidate.voteAverage > 0 {
                Text("·").foregroundStyle(Theme.Colors.textTertiary)
                HStack(spacing: 2) {
                    Image(systemName: "star.fill").foregroundStyle(Theme.Colors.starFilled)
                    Text(String(format: "%.1f", candidate.voteAverage))
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
                .font(Theme.Typography.caption)
            }
        }
    }
}
