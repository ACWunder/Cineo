import Foundation

nonisolated struct LibraryItem: Codable, Identifiable, Hashable, Sendable {
    let tmdbId: Int
    let mediaType: MediaType
    let title: String
    let overview: String
    let year: String
    let posterPath: String?
    let genres: [String]
    var rating: Int?
    var watched: Bool
    let addedAt: Date

    var id: Int { tmdbId }

    var ratingValue: Int { rating ?? 0 }

    var hasRating: Bool { rating != nil }
}

nonisolated struct DismissedItem: Codable, Identifiable, Hashable, Sendable {
    let tmdbId: Int
    let mediaType: MediaType

    var id: Int { tmdbId }
}
