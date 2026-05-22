import SwiftUI

struct LibraryView: View {
    @Environment(LibraryRepository.self) private var library
    @State private var viewModel = LibraryViewModel()

    // Inline TMDB search
    @State private var searchQuery: String = ""
    @State private var searchResults: [TMDBSearchMultiResult] = []
    @State private var searchIsLoading: Bool = false
    @State private var searchError: String?
    @State private var pendingAdd: TMDBSearchMultiResult?

    @FocusState private var searchFocused: Bool

    private let columns = [GridItem(.adaptive(minimum: 168), spacing: Theme.Spacing.md)]

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.background.ignoresSafeArea()
                VStack(spacing: 0) {
                    searchBar
                    if isSearching {
                        searchResultsList
                    } else {
                        libraryGrid
                    }
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

    // MARK: - Library grid (watched = true)

    private var allWatched: [LibraryItem] {
        library.items.filter { $0.watched }
    }

    private var watchedItems: [LibraryItem] {
        viewModel.display(from: allWatched)
    }

    @ViewBuilder
    private var libraryGrid: some View {
        if library.isLoading && library.items.isEmpty {
            LoadingStateView(message: "Lade Bibliothek …")
        } else if allWatched.isEmpty {
            EmptyStateView(
                symbol: "books.vertical",
                title: "Noch nichts gesehen",
                message: "Markiere Filme oder Serien als gesehen — sie landen dann hier mit deiner Bewertung."
            )
        } else {
            ScrollView {
                HStack {
                    sortMenu
                    filterMenu
                    Spacer()
                }
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.top, Theme.Spacing.xs)
                .padding(.bottom, Theme.Spacing.sm)

                if watchedItems.isEmpty {
                    filterEmptyState
                } else {
                    LazyVGrid(columns: columns, spacing: Theme.Spacing.md) {
                        ForEach(watchedItems) { item in
                            NavigationLink(value: item) {
                                LibraryGridCell(item: item)
                            }
                            .buttonStyle(CineoPressStyle(scale: 0.97))
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.bottom, Theme.Spacing.lg)
                }
            }
        }
    }

    private var filterEmptyState: some View {
        VStack(spacing: Theme.Spacing.md) {
            Image(systemName: "line.3.horizontal.decrease.circle")
                .font(.system(size: 40, weight: .light, design: .rounded))
                .foregroundStyle(Theme.Colors.textTertiary)
            Text("Keine Treffer mit diesem Filter")
                .font(Theme.Typography.headline)
                .foregroundStyle(Theme.Colors.textPrimary)
            Text("Setze den Filter zurück, um alle Titel zu sehen.")
                .font(Theme.Typography.callout)
                .foregroundStyle(Theme.Colors.textSecondary)
                .multilineTextAlignment(.center)
            Button {
                viewModel.filter = .all
            } label: {
                Text("Filter zurücksetzen")
                    .font(Theme.Typography.footnote.weight(.semibold))
                    .foregroundStyle(Color(hex: 0x2A1A05))
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.vertical, 9)
                    .background(Theme.Colors.accentGradient, in: Capsule())
                    .overlay(Capsule().stroke(Color.white.opacity(0.22), lineWidth: 0.5))
                    .shadow(color: Theme.Colors.accentGlow, radius: 14, y: 4)
            }
            .buttonStyle(CineoPressStyle(scale: 0.94))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.xxl)
        .padding(.horizontal, Theme.Spacing.lg)
    }

    // MARK: - Search bar + results

    private var trimmedQuery: String {
        searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isSearching: Bool { !trimmedQuery.isEmpty }

    private var searchBar: some View {
        CineoSearchField(
            text: $searchQuery,
            placeholder: "Film oder Serie hinzufügen …",
            focus: $searchFocused
        )
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.top, Theme.Spacing.xs)
        .padding(.bottom, Theme.Spacing.sm)
    }

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
                        SearchResultRow(
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

    // MARK: - Sort + filter

    private var sortMenu: some View {
        @Bindable var vm = viewModel
        return Menu {
            Picker("Sortieren", selection: $vm.sort) {
                ForEach(LibraryViewModel.Sort.allCases) { Text($0.rawValue).tag($0) }
            }
        } label: {
            Label("Sortieren", systemImage: "arrow.up.arrow.down")
                .font(Theme.Typography.footnote.weight(.semibold))
                .foregroundStyle(Theme.Colors.accentLight)
                .padding(.horizontal, Theme.Spacing.sm)
                .padding(.vertical, 6)
                .background(Theme.Colors.surface, in: Capsule())
                .overlay(Capsule().strokeBorder(Theme.Colors.border, lineWidth: 0.5))
        }
    }

    private var filterMenu: some View {
        @Bindable var vm = viewModel
        return Menu {
            Picker("Filter", selection: $vm.filter) {
                ForEach(LibraryViewModel.Filter.allCases) { Text($0.rawValue).tag($0) }
            }
        } label: {
            Label("Filter", systemImage: "line.3.horizontal.decrease.circle")
                .font(Theme.Typography.footnote.weight(.semibold))
                .foregroundStyle(Theme.Colors.accentLight)
                .padding(.horizontal, Theme.Spacing.sm)
                .padding(.vertical, 6)
                .background(Theme.Colors.surface, in: Capsule())
                .overlay(Capsule().strokeBorder(Theme.Colors.border, lineWidth: 0.5))
        }
    }
}

private struct LibraryGridCell: View {
    let item: LibraryItem
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            PosterView(path: item.posterPath, size: "w342", radius: Theme.Radius.md)
            Text(item.title)
                .font(Theme.Typography.callout.weight(.semibold))
                .foregroundStyle(Theme.Colors.textPrimary)
                .lineLimit(2)
            HStack(spacing: 4) {
                if !item.year.isEmpty {
                    Text(item.year)
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
                Spacer()
                if let r = item.rating {
                    StarRatingDisplay(rating: r, size: 11)
                }
            }
        }
    }
}

private struct SearchResultRow: View {
    let result: TMDBSearchMultiResult
    let isInLibrary: Bool
    let onAdd: () -> Void

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            PosterView(path: result.posterPath, size: "w342", radius: Theme.Radius.md, shadow: false)
                .frame(width: 84)

            VStack(alignment: .leading, spacing: 4) {
                Text(result.displayTitle)
                    .font(Theme.Typography.headline)
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .lineLimit(2)

                HStack(spacing: Theme.Spacing.xs) {
                    if let mt = result.resolvedMediaType {
                        Label(mt.displayName, systemImage: mt.symbol)
                            .font(Theme.Typography.caption)
                            .foregroundStyle(Theme.Colors.textSecondary)
                    }
                    if !result.year.isEmpty {
                        Text("·").foregroundStyle(Theme.Colors.textTertiary)
                        Text(result.year)
                            .font(Theme.Typography.caption)
                            .foregroundStyle(Theme.Colors.textSecondary)
                    }
                }
            }

            Spacer()

            Button(action: onAdd) {
                Image(systemName: isInLibrary ? "checkmark.circle.fill" : "plus.circle.fill")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(isInLibrary ? Theme.Colors.success : Theme.Colors.accentLight)
                    .frame(width: 56, height: 56)
            }
            .buttonStyle(CineoPressStyle(scale: 0.9))
            .disabled(isInLibrary)
        }
        .cineoCard(padding: Theme.Spacing.sm)
    }
}
