import Foundation

nonisolated struct LibraryItem: Codable, Identifiable, Hashable, Sendable {
    let tmdbId: Int
    let mediaType: MediaType
    let title: String
    let overview: String
    let year: String
    let posterPath: String?
    let genres: [String]
    var rating: Double?     // 0.5 ... 5.0 in 0.5 steps
    var watched: Bool
    let addedAt: Date

    var id: Int { tmdbId }

    var ratingValue: Double { rating ?? 0 }

    var hasRating: Bool { rating != nil }
}

nonisolated struct DismissedItem: Codable, Identifiable, Hashable, Sendable {
    let tmdbId: Int
    let mediaType: MediaType
    let dismissedAt: Date?

    var id: Int { tmdbId }
}
