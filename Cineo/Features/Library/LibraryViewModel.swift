import Foundation

@MainActor
@Observable
final class LibraryViewModel {

    enum Sort: String, CaseIterable, Identifiable {
        case addedAt = "Hinzugefügt"
        case rating = "Bewertung"
        case title = "Titel"
        var id: String { rawValue }
    }

    enum Filter: String, CaseIterable, Identifiable {
        case all = "Alle"
        case movies = "Filme"
        case tv = "Serien"
        case unrated = "Ohne Bewertung"
        var id: String { rawValue }
    }

    var sort: Sort = .addedAt
    var filter: Filter = .all

    func display(from items: [LibraryItem]) -> [LibraryItem] {
        let filtered = items.filter { item in
            switch filter {
            case .all: true
            case .movies: item.mediaType == .movie
            case .tv: item.mediaType == .tv
            case .unrated: item.rating == nil
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
}
