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
    var selectedGenres: Set<String> = []   // empty = no filter

    var hasActiveFilters: Bool {
        mediaType != .all || minRating > 0 || !selectedGenres.isEmpty
    }

    func display(from items: [LibraryItem]) -> [LibraryItem] {
        var filtered = items

        switch mediaType {
        case .all: break
        case .movies: filtered = filtered.filter { $0.mediaType == .movie }
        case .tv:     filtered = filtered.filter { $0.mediaType == .tv }
        }

        if minRating > 0 {
            filtered = filtered.filter { ($0.rating ?? 0) >= minRating }
        }

        if !selectedGenres.isEmpty {
            filtered = filtered.filter { item in
                !selectedGenres.intersection(item.genres).isEmpty
            }
        }

        switch sort {
        case .addedAt:
            return filtered.sorted(by: { $0.addedAt > $1.addedAt })
        case .rating:
            return filtered.sorted(by: { ($0.rating ?? 0) > ($1.rating ?? 0) })
        case .title:
            return filtered.sorted(by: { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending })
        }
    }

    func resetFilters() {
        mediaType = .all
        minRating = 0
        selectedGenres = []
    }
}
