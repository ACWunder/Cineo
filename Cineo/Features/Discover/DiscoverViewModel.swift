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

    var stack: [Candidate] = []
    var isLoading: Bool = false
    var error: String?
    var emptyLibrary: Bool = false

    private let client = TMDBClient.shared

    func reload(library: [LibraryItem], dismissedIds: Set<Int>) async {
        isLoading = true
        defer { isLoading = false }
        error = nil
        emptyLibrary = false

        try? await client.ensureGenresLoaded()

        let ratedTitles = library.filter { $0.rating != nil && $0.rating != 0 }
        let libraryIds = Set(library.map { $0.tmdbId })

        if ratedTitles.isEmpty {
            emptyLibrary = library.isEmpty
            await loadTrendingFallback(libraryIds: libraryIds, dismissedIds: dismissedIds)
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
        let candidates: [Candidate] = ordered.compactMap { entry in
            guard let rec = seen[entry.key], let mt = typeOf[entry.key] else { return nil }
            let genres = client.resolveGenres(ids: rec.genreIds, mediaType: mt)
            return Candidate(
                tmdbId: rec.id,
                mediaType: mt,
                title: rec.displayTitle,
                year: rec.year,
                overview: rec.overview ?? "",
                posterPath: rec.posterPath,
                genres: genres,
                voteAverage: rec.voteAverage ?? 0
            )
        }

        stack = candidates
    }

    private func loadTrendingFallback(libraryIds: Set<Int>, dismissedIds: Set<Int>) async {
        do {
            let trending = try await client.trending()
            let candidates: [Candidate] = trending.compactMap { res in
                guard let mt = res.resolvedMediaType else { return nil }
                if libraryIds.contains(res.id) { return nil }
                if dismissedIds.contains(res.id) { return nil }
                let genres = client.resolveGenres(ids: res.genreIds, mediaType: mt)
                return Candidate(
                    tmdbId: res.id,
                    mediaType: mt,
                    title: res.displayTitle,
                    year: res.year,
                    overview: res.overview ?? "",
                    posterPath: res.posterPath,
                    genres: genres,
                    voteAverage: res.voteAverage ?? 0
                )
            }
            stack = candidates
        } catch {
            self.error = error.localizedDescription
        }
    }

    func popTop() {
        guard !stack.isEmpty else { return }
        stack.removeFirst()
    }

    func toLibraryItem(_ c: Candidate, rating: Int?, watched: Bool) -> LibraryItem {
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
