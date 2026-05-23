import SwiftUI

struct WatchlistView: View {

    enum MediaFilter: String, CaseIterable, Identifiable {
        case all = "Alle"
        case movies = "Filme"
        case tv = "Serien"
        var id: String { rawValue }
    }

    @Environment(LibraryRepository.self) private var library

    @State private var rateTarget: LibraryItem?
    @State private var mediaFilter: MediaFilter = .all

    // Inline TMDB search
    @State private var searchQuery: String = ""
    @State private var searchResults: [TMDBSearchMultiResult] = []
    @State private var searchIsLoading: Bool = false
    @State private var searchError: String?
    @State private var pendingAdd: TMDBSearchMultiResult?

    @FocusState private var searchFocused: Bool

    private var unwatched: [LibraryItem] {
        let base = library.items.filter { !$0.watched }
        let filtered: [LibraryItem]
        switch mediaFilter {
        case .all:    filtered = base
        case .movies: filtered = base.filter { $0.mediaType == .movie }
        case .tv:     filtered = base.filter { $0.mediaType == .tv }
        }
        return filtered.sorted(by: { $0.addedAt > $1.addedAt })
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.background.ignoresSafeArea()
                VStack(spacing: 0) {
                    CineoSearchField(
                        text: $searchQuery,
                        placeholder: "Film oder Serie hinzufügen …",
                        focus: $searchFocused
                    )
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.top, Theme.Spacing.xs)
                    .padding(.bottom, isSearching ? Theme.Spacing.sm : Theme.Spacing.md)

                    if !isSearching {
                        mediaFilterChips
                            .padding(.horizontal, Theme.Spacing.md)
                            .padding(.bottom, Theme.Spacing.md)
                    }

                    if isSearching {
                        searchResultsList
                    } else {
                        watchlistList
                    }
                }
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
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: LibraryItem.self) { item in
                LibraryDetailView(item: item)
            }
        }
        .task(id: trimmedQuery) {
            try? await Task.sleep(for: .milliseconds(300))
            if Task.isCancelled { return }
            await performSearch()
        }
        .sheet(item: $pendingAdd) { item in
            AddTitleSheet(result: item)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Watchlist list

    @ViewBuilder
    private var watchlistList: some View {
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
                .padding(.bottom, Theme.Spacing.lg)
            }
        }
    }

    // MARK: - Mark watched

    private func commit(_ rating: Double?, for item: LibraryItem) {
        // Optimistic UI: close the overlay first, save in the background.
        withAnimation(.easeOut(duration: 0.25)) {
            rateTarget = nil
        }
        Task { await library.markWatched(tmdbId: item.tmdbId, rating: rating) }
    }

    // MARK: - Search

    private var trimmedQuery: String {
        searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    private var isSearching: Bool { !trimmedQuery.isEmpty }

    @ViewBuilder
    private var searchResultsList: some View {
        if searchIsLoading && searchResults.isEmpty {
            LoadingStateView(message: "Suche …")
        } else if let searchError {
            EmptyStateView(
                symbol: "exclamationmark.triangle",
                title: "Hat nicht geklappt",
                message: searchError
            )
        } else if searchResults.isEmpty {
            EmptyStateView(
                symbol: "moon.zzz",
                title: "Keine Treffer",
                message: "Versuch einen anderen Suchbegriff."
            )
        } else {
            ScrollView {
                LazyVStack(spacing: Theme.Spacing.sm) {
                    ForEach(searchResults, id: \.id) { item in
                        WatchlistSearchRow(
                            result: item,
                            isInLibrary: library.contains(tmdbId: item.id)
                        ) {
                            pendingAdd = item
                        }
                    }
                }
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.vertical, Theme.Spacing.sm)
            }
        }
    }

    private var mediaFilterChips: some View {
        HStack {
            mediaTypeMenu
            Spacer(minLength: 0)
        }
        .animation(nil, value: mediaFilter)
    }

    private var mediaTypeMenu: some View {
        let isActive = mediaFilter != .all
        return Menu {
            ForEach(MediaFilter.allCases) { option in
                Button {
                    DispatchQueue.main.async {
                        var transaction = Transaction()
                        transaction.disablesAnimations = true
                        withTransaction(transaction) {
                            mediaFilter = option
                        }
                    }
                } label: {
                    Label(option.rawValue,
                          systemImage: mediaFilter == option ? "checkmark" : "")
                }
            }
        } label: {
            filterPillLabel(
                icon: "film.stack",
                text: mediaFilter == .all ? "Typ" : mediaFilter.rawValue,
                isActive: isActive
            )
        }
    }

    private func filterPillLabel(icon: String, text: String, isActive: Bool) -> some View {
        FilterPill(icon: icon, text: text, isActive: isActive)
            .id("\(icon)|\(text)|\(isActive)")
    }

    private func performSearch() async {
        let q = trimmedQuery
        guard !q.isEmpty else {
            searchResults = []
            searchError = nil
            return
        }
        searchIsLoading = true
        defer { searchIsLoading = false }
        do {
            let res = try await TMDBClient.shared.searchMulti(query: q)
            searchResults = res
            searchError = nil
        } catch let err as TMDBError {
            searchError = err.localizedDescription
        } catch let err {
            searchError = err.localizedDescription
        }
    }
}

// MARK: - Row

private struct WatchlistRow: View {
    let item: LibraryItem
    let onMarkSeen: () -> Void

    var body: some View {
        ZStack {
            // Tappable content area — pushes the detail view.
            NavigationLink(value: item) {
                HStack(spacing: Theme.Spacing.md) {
                    PosterView(path: item.posterPath, size: "w342", radius: Theme.Radius.md, shadow: false)
                        .frame(width: 72)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(item.title)
                            .font(Theme.Typography.callout.weight(.semibold))
                            .foregroundStyle(Theme.Colors.textPrimary)
                            .lineLimit(2)

                        HStack(spacing: 6) {
                            Image(systemName: item.mediaType.symbol)
                                .font(.system(size: 10, weight: .semibold, design: .rounded))
                            Text(item.mediaType.displayName)
                                .font(Theme.Typography.caption)
                            if !item.year.isEmpty {
                                Text("·").foregroundStyle(Theme.Colors.textTertiary)
                                Text(item.year)
                                    .font(Theme.Typography.caption)
                            }
                        }
                        .foregroundStyle(Theme.Colors.textSecondary)
                    }

                    Spacer(minLength: 0)
                    // Reserve room for the eye on the right.
                    Color.clear.frame(width: 40, height: 1)
                }
                .padding(Theme.Spacing.sm)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Eye sits as an overlay on the right; it intercepts taps so
            // tapping it never pushes the navigation link.
            HStack {
                Spacer()
                Image(systemName: "eye.fill")
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.Colors.accent)
                    .shadow(color: Theme.Colors.accentGlow.opacity(0.5), radius: 6, y: 1)
                    .padding(Theme.Spacing.sm)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        onMarkSeen()
                    }
                    .accessibilityLabel("Als gesehen markieren")
            }
            .padding(.trailing, Theme.Spacing.xs)
        }
        .cineoRow(padding: 0)
    }
}

private struct WatchlistSearchRow: View {
    let result: TMDBSearchMultiResult
    let isInLibrary: Bool
    let onAdd: () -> Void

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            PosterView(path: result.posterPath, size: "w342", radius: Theme.Radius.md, shadow: false)
                .frame(width: 72)

            VStack(alignment: .leading, spacing: 3) {
                Text(result.displayTitle)
                    .font(Theme.Typography.callout.weight(.semibold))
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .lineLimit(2)
                HStack(spacing: 6) {
                    if let mt = result.resolvedMediaType {
                        Image(systemName: mt.symbol)
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                        Text(mt.displayName).font(Theme.Typography.caption)
                    }
                    if !result.year.isEmpty {
                        Text("·").foregroundStyle(Theme.Colors.textTertiary)
                        Text(result.year).font(Theme.Typography.caption)
                    }
                }
                .foregroundStyle(Theme.Colors.textSecondary)
            }

            Spacer()

            Button(action: onAdd) {
                Image(systemName: isInLibrary ? "checkmark.circle.fill" : "plus.circle.fill")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(isInLibrary ? Theme.Colors.success : Theme.Colors.accent)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(CineoPressStyle(scale: 0.9))
            .disabled(isInLibrary)
        }
        .cineoRow(padding: Theme.Spacing.sm)
    }
}
