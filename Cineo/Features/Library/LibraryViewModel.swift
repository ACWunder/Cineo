import Foundation

@MainActor
@Observable
final class LibraryViewModel {

    enum Sort: String, CaseIterable, Identifiable {
        case addedAt = "Hinzugefügt"
        case rating = "Bewertung"
        case title = "Titel"
        var id: String { rawValue }

        var symbol: String {
            switch self {
            case .addedAt: "clock"
            case .rating: "star.fill"
            case .title: "textformat"
            }
        }
    }

    enum MediaTypeFilter: String, CaseIterable, Identifiable {
        case all = "Alle"
        case movies = "Filme"
        case tv = "Serien"
        var id: String { rawValue }
    }

    var sort: Sort = .addedAt
    var mediaType: MediaTypeFilter = .all
    var minRating: Int = 0                 // 0 = no filter, 1...5 = ab N Sterne
    var excludedGenres: Set<String> = []   // empty = no filter, otherwise these genres are hidden

    var hasActiveFilters: Bool {
        mediaType != .all || minRating > 0 || !excludedGenres.isEmpty
    }

    func display(from items: [LibraryItem]) -> [LibraryItem] {
        var filtered = items

        switch mediaType {
        case .all: break
        case .movies: filtered = filtered.filter { $0.mediaType == .movie }
        case .tv:     filtered = filtered.filter { $0.mediaType == .tv }
        }

        if minRating > 0 {
            filtered = filtered.filter { ($0.rating ?? 0) >= Double(minRating) }
        }

        if !excludedGenres.isEmpty {
            // OR semantics: keep an item if *any* of its genres is
            // still wanted (i.e. not in the excluded set). A film
            // tagged Action + Sci-Fi survives a "Sci-Fi excluded"
            // filter because Action is still wanted.
            filtered = filtered.filter { item in
                item.genres.contains(where: { !excludedGenres.contains($0) })
            }
        }

        switch sort {
        case .addedAt:
            return filtered.sorted(by: { $0.addedAt > $1.addedAt })
        case .rating:
            return filtered.sorted(by: { ($0.rating ?? 0.0) > ($1.rating ?? 0.0) })
        case .title:
            return filtered.sorted(by: { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending })
        }
    }

    func resetFilters() {
        mediaType = .all
        minRating = 0
        excludedGenres = []
    }
}
