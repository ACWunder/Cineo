import SwiftUI

struct WatchlistView: View {

    @Environment(LibraryRepository.self) private var library
    @State private var rateTarget: LibraryItem?

    private var unwatched: [LibraryItem] {
        library.items
            .filter { !$0.watched }
            .sorted(by: { $0.addedAt > $1.addedAt })
    }

    var body: some View {
        ZStack {
            Theme.Colors.background.ignoresSafeArea()
            content
            if let item = rateTarget {
                RatingOverlay(
                    title: item.title,
                    posterPath: item.posterPath,
                    onRate: { value in commit(value, for: item) },
                    onSkip: { commit(nil, for: item) },
                    onCancel: { rateTarget = nil }
                )
                .zIndex(99)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if library.isLoading && library.items.isEmpty {
            LoadingStateView(message: "Lade Watchlist …")
        } else if unwatched.isEmpty {
            EmptyStateView(
                symbol: "bookmark",
                title: "Watchlist ist leer",
                message: "Tippe in der Suche oder bei Empfehlungen auf das Plus, um Titel hier zu merken."
            )
        } else {
            ScrollView {
                LazyVStack(spacing: Theme.Spacing.sm) {
                    ForEach(unwatched) { item in
                        WatchlistRow(item: item) {
                            rateTarget = item
                        }
                    }
                }
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.top, Theme.Spacing.sm)
                .padding(.bottom, Theme.Spacing.lg)
            }
        }
    }

    private func commit(_ rating: Int?, for item: LibraryItem) {
        Task {
            await library.markWatched(tmdbId: item.tmdbId, rating: rating)
            rateTarget = nil
        }
    }
}

private struct WatchlistRow: View {
    let item: LibraryItem
    let onMarkSeen: () -> Void

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            PosterView(path: item.posterPath, size: "w342", radius: Theme.Radius.md, shadow: false)
                .frame(width: 84)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(Theme.Typography.headline)
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .lineLimit(2)

                HStack(spacing: Theme.Spacing.xs) {
                    Label(item.mediaType.displayName, systemImage: item.mediaType.symbol)
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Colors.textSecondary)
                    if !item.year.isEmpty {
                        Text("·").foregroundStyle(Theme.Colors.textTertiary)
                        Text(item.year)
                            .font(Theme.Typography.caption)
                            .foregroundStyle(Theme.Colors.textSecondary)
                    }
                }
            }

            Spacer()

            Button(action: onMarkSeen) {
                Image(systemName: "eye.fill")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .frame(width: 56, height: 56)
                    .background(Theme.Colors.accentGradient, in: Circle())
                    .shadow(color: Theme.Colors.accentGlow, radius: 14, y: 6)
            }
            .buttonStyle(CineoPressStyle(scale: 0.9))
            .accessibilityLabel("Als gesehen markieren")
        }
        .cineoCard(padding: Theme.Spacing.sm)
    }
}
