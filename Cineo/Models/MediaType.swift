import Foundation

enum MediaType: String, Codable, Hashable, Sendable, CaseIterable {
    case movie
    case tv

    var displayName: String {
        switch self {
        case .movie: "Film"
        case .tv: "Serie"
        }
    }

    var symbol: String {
        switch self {
        case .movie: "film.fill"
        case .tv: "tv.fill"
        }
    }
}
