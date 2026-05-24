import Foundation

@MainActor
@Observable
final class DiscoverViewModel {

    struct Candidate: Identifiable, Hashable {
        let tmdbId: Int
        let mediaType: MediaType
        let title: String
        let year: String
        let overview: String
        let posterPath: String?
        let genres: [String]
        let voteAverage: Double

        var id: Int { tmdbId }
    }

    enum MediaFilter: String, CaseIterable, Identifiable, Sendable {
        case all
        case movie
        case tv

        var id: String { rawValue }
        var label: String {
            switch self {
            case .all: "Alle"
            case .movie: "Filme"
            case .tv: "Serien"
            }
        }
    }

    enum SourceMode: String, CaseIterable, Identifiable, Sendable {
        case library     // recommendations derived from the user's ratings
        case trending    // TMDB's weekly trending list, ignores the library

        var id: String { rawValue }
        var label: String {
            switch self {
            case .library: "Für dich"
            case .trending: "Angesagt"
            }
        }
        var icon: String {
            switch self {
            case .library: "sparkles"
            case .trending: "flame.fill"
            }
        }
    }

    /// Authoritative pool — the full list of candidates from the latest reload.
    private var allCandidates: [Candidate] = [] {
        didSet { rebuildFilterCaches() }
    }
    /// Pre-filtered slices so switching the filter chip is just a pointer
    /// assignment — no per-tap O(n) scan, no main-thread spike.
    private var moviesCache: [Candidate] = []
    private var tvCache: [Candidate] = []

    var stack: [Candidate] = []
    var filter: MediaFilter = .all { didSet { applyFilter() } }
    /// Exclusion model — mirrors LibraryView. Empty = no filter; any genre
    /// in this set is hidden from the deck (OR semantics: a candidate stays
    /// if at least one of its genres is *not* excluded).
    var excludedGenres: Set<String> = [] { didSet { applyFilter() } }
    var sourceMode: SourceMode = .library    // reload trigger lives in the view
    var isLoading: Bool = false
    var error: String?
    var emptyLibrary: Bool = false

    /// Pagination state. Reset on every full `reload`; mutated by `loadMore`.
    /// `seenIds` is the dedupe shield — any candidate ever placed into the
    /// pool stays out of later pages, so swiped/popped cards never re-appear.
    private(set) var isLoadingMore: Bool = false
    private(set) var isExhausted: Bool = false
    private var seenIds: Set<Int> = []
    private var nextLibraryPage: Int = 2
    private var nextTrendingPage: Int = 2

    /// Bumped at the start of every full reload. Any reload that finishes
    /// while a newer one is already in flight discards its result, so rapid
    /// toggle taps always converge on the latest selection's data.
    private var reloadGeneration: Int = 0

    private let client = TMDBClient.shared

    /// Filter out titles that aren't written in the Latin alphabet —
    /// Japanese / Chinese / Korean / Arabic / Devanagari / Thai / Hebrew /
    /// Cyrillic etc. all get dropped. Diacritics for Western European
    /// languages (é, ø, ñ, …) and Vietnamese (Latin Extended Additional)
    /// stay in. A title with zero alphabetic characters (rare, e.g. "404")
    /// is allowed through.
    private nonisolated static func isLatinTitle(_ title: String) -> Bool {
        for scalar in title.unicodeScalars {
            guard scalar.properties.isAlphabetic else { continue }
            let v = scalar.value
            if v <= 0x024F { continue }                       // Basic Latin + Latin-1 + Extended A/B
            if v >= 0x1E00 && v <= 0x1EFF { continue }        // Latin Extended Additional
            return false
        }
        return true
    }

    /// Unique genres present in the current pool — used to populate the
    /// genre menu. Empty until a reload has run.
    var availableGenres: [String] {
        var seen = Set<String>()
        for c in allCandidates {
            for g in c.genres { seen.insert(g) }
        }
        return seen.sorted()
    }

    private func rebuildFilterCaches() {
        moviesCache = allCandidates.filter { $0.mediaType == .movie }
        tvCache = allCandidates.filter { $0.mediaType == .tv }
    }

    private func applyFilter() {
        let base: [Candidate]
        switch filter {
        case .all:   base = allCandidates
        case .movie: base = moviesCache
        case .tv:    base = tvCache
        }
        if excludedGenres.isEmpty {
            stack = base
        } else {
            // Same OR semantics as LibraryViewModel: keep a candidate if at
            // least one of its genres is not in the exclusion set.
            stack = base.filter { c in
                c.genres.contains(where: { !excludedGenres.contains($0) })
            }
        }
    }

    func reload(library: [LibraryItem],
                dismissedAtById: [Int: Date],
                preserveVisible: Int = 0) async {
        reloadGeneration += 1
        let myGen = reloadGeneration

        isLoading = true
        error = nil
        emptyLibrary = false

        // Drop the visible deck on a fresh reload so the loading state
        // takes over immediately instead of showing the previous mode's
        // leftovers. The library-count path keeps `preserveVisible > 0`
        // to hold the head stable while the pool reranks underneath.
        //
        // applyFilter() is required because allCandidates.didSet only
        // rebuilds the type caches — `stack` (what the view binds to)
        // wouldn't clear otherwise, and the user would keep seeing the
        // old cards for the whole network round-trip.
        if preserveVisible == 0 {
            allCandidates = []
            applyFilter()
        }

        // Fresh pool → fresh pagination state.
        seenIds = []
        nextLibraryPage = 2
        nextTrendingPage = 2
        isExhausted = false

        try? await client.ensureGenresLoaded()

        let ratedTitles = library.filter { $0.rating != nil && $0.rating != 0 }
        let libraryIds = Set(library.map { $0.tmdbId })

        // Snapshot whatever the user can currently see, but drop anything
        // that has since been added to library / watchlist / dismissed — so
        // a card the user just added isn't kept in the preserved head.
        let preservedHead: [Candidate] = {
            guard preserveVisible > 0 else { return [] }
            return Array(stack.prefix(preserveVisible)).filter { c in
                !libraryIds.contains(c.tmdbId) && dismissedAtById[c.tmdbId] == nil
            }
        }()

        // Trending mode bypasses the library scoring entirely. The user is
        // explicitly asking for "what's hot right now"; their ratings don't
        // come into it.
        if sourceMode == .trending {
            emptyLibrary = false
            await loadTrendingFallback(libraryIds: libraryIds, dismissedAtById: dismissedAtById, preservedHead: preservedHead, generation: myGen)
            return
        }

        if ratedTitles.isEmpty {
            emptyLibrary = library.isEmpty
            await loadTrendingFallback(libraryIds: libraryIds, dismissedAtById: dismissedAtById, preservedHead: preservedHead, generation: myGen)
            return
        }

        // Revival rule: a dismissed candidate stays out for 7 days, period.
        // After that it can only resurface if its accumulated recommendation
        // score lands in the absolute top of the pool — otherwise the deck
        // would repeat the same dismissed cards every 7 days.
        let now = Date()
        let revivalWindow: TimeInterval = 7 * 24 * 3600
        let revivalTopN = 3

        var scores: [Int: Double] = [:]
        var seen: [Int: TMDBRecommendation] = [:]
        var typeOf: [Int: MediaType] = [:]

        for item in ratedTitles {
            let weight = Double(item.rating ?? 0)
            guard weight > 0 else { continue }

            async let recs = (try? client.recommendations(for: item.tmdbId, mediaType: item.mediaType)) ?? []
            async let sims = (try? client.similar(for: item.tmdbId, mediaType: item.mediaType)) ?? []
            let combined = await (recs + sims)

            for rec in combined {
                if libraryIds.contains(rec.id) { continue }
                if let dAt = dismissedAtById[rec.id],
                   now.timeIntervalSince(dAt) < revivalWindow {
                    continue
                }
                guard Self.isLatinTitle(rec.displayTitle) else { continue }
                let mtRaw = rec.mediaType ?? item.mediaType.rawValue
                guard let mt = MediaType(rawValue: mtRaw) else { continue }

                let vote = rec.voteAverage ?? 0
                let score = weight * (vote / 10.0)
                scores[rec.id, default: 0] += score
                seen[rec.id] = rec
                typeOf[rec.id] = mt
            }
        }

        let ordered = scores.sorted(by: { $0.value > $1.value })
        // Only the absolute top of the ranking can resurface from the
        // dismissed pile. Everything else, even if past the 7-day window,
        // is filtered out so the user doesn't keep seeing the same
        // borderline candidates.
        let revivalEligibleIds: Set<Int> = Set(ordered.prefix(revivalTopN).map { $0.key })

        var candidates: [Candidate] = []
        for entry in ordered {
            let wasDismissed = dismissedAtById[entry.key] != nil
            if wasDismissed && !revivalEligibleIds.contains(entry.key) { continue }
            guard let rec = seen[entry.key], let mt = typeOf[entry.key] else { continue }
            let genres = await client.resolveGenres(ids: rec.genreIds, mediaType: mt)
            candidates.append(Candidate(
                tmdbId: rec.id,
                mediaType: mt,
                title: rec.displayTitle,
                year: rec.year,
                overview: rec.overview ?? "",
                posterPath: rec.posterPath,
                genres: genres,
                voteAverage: rec.voteAverage ?? 0
            ))
        }

        // A newer reload has bumped the generation — drop our work so the
        // user only sees the latest selection's pool, never an in-flight
        // stale one bleeding into the view.
        guard myGen == reloadGeneration else { return }

        let merged = mergePreserved(preservedHead, into: candidates)
        allCandidates = merged
        seenIds = Set(merged.map(\.id))
        applyFilter()
        isLoading = false
    }

    private func loadTrendingFallback(libraryIds: Set<Int>,
                                      dismissedAtById: [Int: Date],
                                      preservedHead: [Candidate] = [],
                                      generation: Int) async {
        // Trending uses a *time-windowed* dismissal rule, not a hard
        // permanent block: anything dismissed within the last 7 days
        // stays out, but older dismissals are eligible again so the
        // "Angesagt" deck always cycles back to fresh content. Walk
        // forward through pages until we collect at least one candidate
        // or hit a page TMDB returns empty (true exhaustion).
        let now = Date()
        let revivalWindow: TimeInterval = 7 * 24 * 3600
        let maxAttempts = 5
        var collected: [Candidate] = []

        for _ in 0..<maxAttempts {
            let page = nextTrendingPage
            let trending: [TMDBSearchMultiResult]
            do {
                trending = try await client.trending(page: page)
            } catch {
                guard generation == reloadGeneration else { return }
                self.error = error.localizedDescription
                isLoading = false
                return
            }
            guard generation == reloadGeneration else { return }

            if trending.isEmpty {
                isExhausted = true
                break
            }
            nextTrendingPage += 1

            for res in trending {
                guard let mt = res.resolvedMediaType else { continue }
                if libraryIds.contains(res.id) { continue }
                if let dAt = dismissedAtById[res.id],
                   now.timeIntervalSince(dAt) < revivalWindow {
                    continue
                }
                guard Self.isLatinTitle(res.displayTitle) else { continue }
                let genres = await client.resolveGenres(ids: res.genreIds, mediaType: mt)
                collected.append(Candidate(
                    tmdbId: res.id,
                    mediaType: mt,
                    title: res.displayTitle,
                    year: res.year,
                    overview: res.overview ?? "",
                    posterPath: res.posterPath,
                    genres: genres,
                    voteAverage: res.voteAverage ?? 0
                ))
            }
            guard generation == reloadGeneration else { return }

            if !collected.isEmpty { break }
        }

        guard generation == reloadGeneration else { return }
        let merged = mergePreserved(preservedHead, into: collected)
        allCandidates = merged
        seenIds = Set(merged.map(\.id))
        applyFilter()
        isLoading = false
    }

    // MARK: - Pagination

    /// Pull the next page in the current source mode and append non-duplicate,
    /// non-library, non-dismissed candidates to the pool. Triggered by the
    /// view when the visible stack drops below its low-water mark.
    func loadMore(library: [LibraryItem], dismissedAtById: [Int: Date]) async {
        // Stay out of the way of a full reload — otherwise loadMore and
        // reload race on the same allCandidates write, and the user can
        // end up seeing the wrong mode's data.
        guard !isLoading, !isLoadingMore, !isExhausted else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }

        // Capture the generation a full reload would bump. If the user
        // toggles the source mid-pagination, the pool has been replaced
        // and these results no longer belong to the visible deck.
        let myGen = reloadGeneration
        let libraryIds = Set(library.map(\.tmdbId))

        switch sourceMode {
        case .library:
            // Library pagination keeps the strict block — appended tail
            // shouldn't re-introduce dismissed cards (the 7-day revival
            // only fires for the absolute top 3 of the initial reload).
            let dismissedIds = Set(dismissedAtById.keys)
            await loadMoreLibrary(library: library, libraryIds: libraryIds, dismissedIds: dismissedIds, generation: myGen)
        case .trending:
            // Trending pagination uses the same 7-day window as the
            // initial trending pull — keeps the deck cycling.
            await loadMoreTrending(libraryIds: libraryIds, dismissedAtById: dismissedAtById, generation: myGen)
        }
    }

    private func loadMoreLibrary(library: [LibraryItem],
                                 libraryIds: Set<Int>,
                                 dismissedIds: Set<Int>,
                                 generation: Int) async {
        let ratedTitles = library.filter { $0.rating != nil && $0.rating != 0 }
        guard !ratedTitles.isEmpty else { isExhausted = true; return }

        let page = nextLibraryPage
        var scores: [Int: Double] = [:]
        var seen: [Int: TMDBRecommendation] = [:]
        var typeOf: [Int: MediaType] = [:]

        for item in ratedTitles {
            let weight = Double(item.rating ?? 0)
            guard weight > 0 else { continue }
            async let recs = (try? client.recommendations(for: item.tmdbId, mediaType: item.mediaType, page: page)) ?? []
            async let sims = (try? client.similar(for: item.tmdbId, mediaType: item.mediaType, page: page)) ?? []
            let combined = await (recs + sims)

            for rec in combined {
                // Pagination excludes every dismissal regardless of age —
                // the 7-day revival only fires on the *initial* reload via
                // the top-3 rule. Append-time isn't where revivals belong.
                if libraryIds.contains(rec.id) { continue }
                if dismissedIds.contains(rec.id) { continue }
                if seenIds.contains(rec.id) { continue }
                guard Self.isLatinTitle(rec.displayTitle) else { continue }
                let mtRaw = rec.mediaType ?? item.mediaType.rawValue
                guard let mt = MediaType(rawValue: mtRaw) else { continue }
                let vote = rec.voteAverage ?? 0
                let score = weight * (vote / 10.0)
                scores[rec.id, default: 0] += score
                seen[rec.id] = rec
                typeOf[rec.id] = mt
            }
        }

        if scores.isEmpty {
            isExhausted = true
            return
        }

        let ordered = scores.sorted(by: { $0.value > $1.value })
        var fresh: [Candidate] = []
        for entry in ordered {
            guard let rec = seen[entry.key], let mt = typeOf[entry.key] else { continue }
            let genres = await client.resolveGenres(ids: rec.genreIds, mediaType: mt)
            fresh.append(Candidate(
                tmdbId: rec.id,
                mediaType: mt,
                title: rec.displayTitle,
                year: rec.year,
                overview: rec.overview ?? "",
                posterPath: rec.posterPath,
                genres: genres,
                voteAverage: rec.voteAverage ?? 0
            ))
        }

        guard generation == reloadGeneration else { return }
        appendToPool(fresh)
        nextLibraryPage += 1
    }

    private func loadMoreTrending(libraryIds: Set<Int>, dismissedAtById: [Int: Date], generation: Int) async {
        // Same loop logic as loadTrendingFallback — if a page is fully
        // filtered out, advance to the next instead of exhausting.
        let now = Date()
        let revivalWindow: TimeInterval = 7 * 24 * 3600
        let maxAttempts = 5
        var fresh: [Candidate] = []

        for _ in 0..<maxAttempts {
            let page = nextTrendingPage
            let results: [TMDBSearchMultiResult]
            do {
                results = try await client.trending(page: page)
            } catch {
                self.error = error.localizedDescription
                return
            }
            guard generation == reloadGeneration else { return }

            if results.isEmpty {
                isExhausted = true
                break
            }
            nextTrendingPage += 1

            for res in results {
                guard let mt = res.resolvedMediaType else { continue }
                if libraryIds.contains(res.id) { continue }
                if seenIds.contains(res.id) { continue }
                if let dAt = dismissedAtById[res.id],
                   now.timeIntervalSince(dAt) < revivalWindow {
                    continue
                }
                guard Self.isLatinTitle(res.displayTitle) else { continue }
                let genres = await client.resolveGenres(ids: res.genreIds, mediaType: mt)
                fresh.append(Candidate(
                    tmdbId: res.id,
                    mediaType: mt,
                    title: res.displayTitle,
                    year: res.year,
                    overview: res.overview ?? "",
                    posterPath: res.posterPath,
                    genres: genres,
                    voteAverage: res.voteAverage ?? 0
                ))
            }
            guard generation == reloadGeneration else { return }

            if !fresh.isEmpty { break }
        }

        guard generation == reloadGeneration else { return }
        if !fresh.isEmpty {
            appendToPool(fresh)
        }
    }

    private func appendToPool(_ fresh: [Candidate]) {
        guard !fresh.isEmpty else { return }
        // Append rather than re-sort: the user is mid-deck, the existing
        // head must stay rock-stable. New cards land at the tail.
        var updated = allCandidates
        updated.append(contentsOf: fresh)
        allCandidates = updated
        for c in fresh { seenIds.insert(c.id) }
        applyFilter()
    }

    /// Keeps every card the user can currently see in place. The recomputation
    /// only touches what was off-screen anyway.
    private func mergePreserved(_ head: [Candidate], into pool: [Candidate]) -> [Candidate] {
        guard !head.isEmpty else { return pool }
        let headIds = Set(head.map(\.id))
        let rest = pool.filter { !headIds.contains($0.id) }
        return head + rest
    }

    func popTop() {
        guard !stack.isEmpty else { return }
        let removed = stack.removeFirst()
        allCandidates.removeAll(where: { $0.id == removed.id })
    }

    /// Restore a previously-popped candidate to the very top of the deck.
    /// Used by the undo button in DiscoverView. If the candidate is already
    /// in the pool (rare race), this is effectively a no-op move-to-front.
    func unshift(_ candidate: Candidate) {
        allCandidates.removeAll(where: { $0.id == candidate.id })
        allCandidates.insert(candidate, at: 0)
        applyFilter()
    }

    /// Strip every candidate whose id is in `ids` from the pool. Used by
    /// DiscoverView after `reload` finishes to catch anything the user
    /// dismissed *while* the reload was in flight — the in-flight reload
    /// snapshotted its `dismissedIds` at the start and can't see later
    /// dismissals, so we filter them out here.
    func removeIDs(_ ids: Set<Int>) {
        guard !ids.isEmpty else { return }
        stack.removeAll { ids.contains($0.id) }
        allCandidates.removeAll { ids.contains($0.id) }
    }

    func toLibraryItem(_ c: Candidate, rating: Double?, watched: Bool) -> LibraryItem {
        LibraryItem(
            tmdbId: c.tmdbId,
            mediaType: c.mediaType,
            title: c.title,
            overview: c.overview,
            year: c.year,
            posterPath: c.posterPath,
            genres: c.genres,
            rating: rating,
            watched: watched,
            addedAt: Date()
        )
    }
}
