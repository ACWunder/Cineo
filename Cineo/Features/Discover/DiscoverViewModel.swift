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

    private var allCandidates: [Candidate] = []
    var stack: [Candidate] = []
    var filter: MediaFilter = .all { didSet { applyFilter() } }
    var isLoading: Bool = false
    var error: String?
    var emptyLibrary: Bool = false

    private let client = TMDBClient.shared

    private func applyFilter() {
        switch filter {
        case .all:
            stack = allCandidates
        case .movie:
            stack = allCandidates.filter { $0.mediaType == .movie }
        case .tv:
            stack = allCandidates.filter { $0.mediaType == .tv }
        }
    }

    func reload(library: [LibraryItem],
                dismissedIds: Set<Int>,
                preserveVisible: Int = 0) async {
        isLoading = true
        defer { isLoading = false }
        error = nil
        emptyLibrary = false

        try? await client.ensureGenresLoaded()

        let ratedTitles = library.filter { $0.rating != nil && $0.rating != 0 }
        let libraryIds = Set(library.map { $0.tmdbId })

        // Snapshot whatever the user can currently see, but drop anything
        // that has since been added to library / watchlist / dismissed — so
        // a card the user just added isn't kept in the preserved head.
        let preservedHead: [Candidate] = {
            guard preserveVisible > 0 else { return [] }
            return Array(stack.prefix(preserveVisible)).filter { c in
                !libraryIds.contains(c.tmdbId) && !dismissedIds.contains(c.tmdbId)
            }
        }()

        if ratedTitles.isEmpty {
            emptyLibrary = library.isEmpty
            await loadTrendingFallback(libraryIds: libraryIds, dismissedIds: dismissedIds, preservedHead: preservedHead)
            return
        }

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
                if dismissedIds.contains(rec.id) { continue }
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
        var candidates: [Candidate] = []
        for entry in ordered {
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

        allCandidates = mergePreserved(preservedHead, into: candidates)
        applyFilter()
    }

    private func loadTrendingFallback(libraryIds: Set<Int>,
                                      dismissedIds: Set<Int>,
                                      preservedHead: [Candidate] = []) async {
        do {
            let trending = try await client.trending()
            var candidates: [Candidate] = []
            for res in trending {
                guard let mt = res.resolvedMediaType else { continue }
                if libraryIds.contains(res.id) { continue }
                if dismissedIds.contains(res.id) { continue }
                let genres = await client.resolveGenres(ids: res.genreIds, mediaType: mt)
                candidates.append(Candidate(
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
            allCandidates = mergePreserved(preservedHead, into: candidates)
            applyFilter()
        } catch {
            self.error = error.localizedDescription
        }
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
