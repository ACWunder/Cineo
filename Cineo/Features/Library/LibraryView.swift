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

    /// Height the filter strip overlay occupies. Stays pinned to the top
    /// of the grid; content scrolls *under* it because the strip has a
    /// transparent background.
    private let filterStripHeight: CGFloat = 48

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
            // Filter strip lives as an overlay above the ScrollView so its
            // visibility never changes the underlying layout — that was the
            // source of the jitter/pause.
            ZStack(alignment: .top) {
                ScrollView {
                    VStack(spacing: 0) {
                        // Reserved spacer that lets the first row of cells
                        // start below the floating filter strip.
                        Color.clear.frame(height: filterStripHeight)

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

                // Stays pinned to the top, transparent background so the
                // grid scrolls *under* the chips instead of being clipped
                // by an opaque strip.
                filterStrip
                    .padding(.horizontal, Theme.Spacing.md)
                    .frame(height: filterStripHeight)
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
                viewModel.resetFilters()
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

    // MARK: - Filter strip

    private var filterStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Spacing.xs) {
                sortMenu
                mediaTypeMenu
                ratingMenu
                genreMenu
            }
            .padding(.horizontal, Theme.Spacing.md)
        }
        .scrollClipDisabled()
    }

    private var sortMenu: some View {
        @Bindable var vm = viewModel
        return Menu {
            Picker("Sortieren", selection: $vm.sort) {
                ForEach(LibraryViewModel.Sort.allCases) { sort in
                    Label(sort.rawValue, systemImage: sort.symbol).tag(sort)
                }
            }
        } label: {
            Image(systemName: "arrow.up.arrow.down")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.Colors.accentLight)
                .frame(width: 34, height: 34)
                .background(.ultraThinMaterial.opacity(0.4), in: Circle())
                .overlay(
                    Circle().stroke(
                        LinearGradient(
                            colors: [Color.white.opacity(0.14), Color.white.opacity(0.03)],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 0.5
                    )
                )
        }
    }

    private var mediaTypeMenu: some View {
        @Bindable var vm = viewModel
        let isActive = vm.mediaType != .all
        return Menu {
            ForEach(LibraryViewModel.MediaTypeFilter.allCases) { option in
                Button {
                    vm.mediaType = option
                } label: {
                    Label(option.rawValue,
                          systemImage: vm.mediaType == option ? "checkmark" : "")
                }
            }
        } label: {
            filterPillLabel(
                icon: "film.stack",
                text: vm.mediaType == .all ? "Typ" : vm.mediaType.rawValue,
                isActive: isActive
            )
        }
    }

    private var ratingMenu: some View {
        @Bindable var vm = viewModel
        let isActive = vm.minRating > 0
        return Menu {
            Button {
                vm.minRating = 0
            } label: {
                Label("Alle Bewertungen", systemImage: vm.minRating == 0 ? "checkmark" : "")
            }
            Divider()
            ForEach(Array((1...5).reversed()), id: \.self) { stars in
                Button {
                    vm.minRating = stars
                } label: {
                    Label("ab \(stars) \(stars == 1 ? "Stern" : "Sternen")",
                          systemImage: vm.minRating == stars ? "checkmark" : "")
                }
            }
        } label: {
            filterPillLabel(
                icon: "star.fill",
                text: isActive ? "ab \(vm.minRating)\u{2009}\u{2605}" : "Bewertung",
                isActive: isActive
            )
        }
    }

    private var genreMenu: some View {
        @Bindable var vm = viewModel
        let genres = uniqueGenres()
        let isActive = !vm.selectedGenres.isEmpty
        return Menu {
            if isActive {
                Button("Alle Genres zurücksetzen", role: .destructive) {
                    vm.selectedGenres = []
                }
                Divider()
            }
            ForEach(genres, id: \.self) { genre in
                Button {
                    if vm.selectedGenres.contains(genre) {
                        vm.selectedGenres.remove(genre)
                    } else {
                        vm.selectedGenres.insert(genre)
                    }
                } label: {
                    Label(genre, systemImage: vm.selectedGenres.contains(genre) ? "checkmark" : "")
                }
                .menuActionDismissBehavior(.disabled)
            }
        } label: {
            let count = vm.selectedGenres.count
            filterPillLabel(
                icon: "tag.fill",
                text: isActive ? "Genre · \(count)" : "Genre",
                isActive: isActive
            )
        }
        .disabled(genres.isEmpty)
    }

    private func filterPillLabel(icon: String, text: String, isActive: Bool) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
            Text(text)
                .font(Theme.Typography.footnote.weight(.semibold))
            Image(systemName: "chevron.down")
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .opacity(0.7)
        }
        .foregroundStyle(isActive ? Color(hex: 0x2A1A05) : Theme.Colors.textPrimary)
        .padding(.horizontal, Theme.Spacing.sm)
        .padding(.vertical, 7)
        .background(
            ZStack {
                if isActive {
                    Capsule().fill(Theme.Colors.accentGradient)
                    Capsule()
                        .fill(Theme.Colors.accentSheen)
                        .blendMode(.plusLighter)
                        .allowsHitTesting(false)
                } else {
                    Capsule().fill(.ultraThinMaterial.opacity(0.4))
                }
            }
        )
        .overlay(
            Capsule().stroke(
                isActive ? Color.white.opacity(0.28) : Theme.Colors.border,
                lineWidth: 0.5
            )
        )
        .shadow(
            color: isActive ? Theme.Colors.accentGlow.opacity(0.55) : .clear,
            radius: 10, y: 4
        )
    }

    /// Unique sorted genres harvested from the user's watched library — feeds
    /// the multi-select Genre menu.
    private func uniqueGenres() -> [String] {
        var seen = Set<String>()
        for item in library.items where item.watched {
            for g in item.genres { seen.insert(g) }
        }
        return seen.sorted()
    }
}

private struct LibraryGridCell: View {
    let item: LibraryItem

    /// Fixed height for the text block under each poster. Sized to fit a
    /// 2-line title + meta line; shorter titles get an invisible spacer
    /// at the bottom so the total cell height (and therefore the cover
    /// spacing in the grid) stays identical for every entry.
    private let textBlockHeight: CGFloat = 62

    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            PosterView(path: item.posterPath, size: "w342", radius: Theme.Radius.md)
                .frame(maxWidth: .infinity)

            // Title + meta sit centered inside a fixed-height frame. With
            // a 1-line title the equal spacers above and below put the
            // text block visually in the middle, leaving a clear gap to
            // the cover. With a 2-line title the spacers collapse to 0
            // and the block fills the frame naturally.
            VStack(spacing: 0) {
                Spacer(minLength: 0)

                Text(item.title)
                    .font(Theme.Typography.callout.weight(.semibold))
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity)

                HStack(spacing: 6) {
                    if !item.year.isEmpty {
                        Text(item.year)
                            .font(Theme.Typography.caption)
                            .foregroundStyle(Theme.Colors.textSecondary)
                    }
                    if let r = item.rating, r > 0 {
                        StarRatingDisplay(rating: r, size: 11)
                    } else {
                        Text("—")
                            .font(Theme.Typography.caption)
                            .foregroundStyle(Theme.Colors.textTertiary)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 14)
                .padding(.top, Theme.Spacing.xxs)

                Spacer(minLength: 0)
            }
            .frame(height: textBlockHeight)
            .padding(.top, Theme.Spacing.xs)
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
