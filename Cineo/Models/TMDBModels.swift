import Foundation

struct TMDBGenre: Decodable, Hashable, Sendable {
    let id: Int
    let name: String
}

struct TMDBGenresResponse: Decodable, Sendable {
    let genres: [TMDBGenre]
}

struct TMDBSearchMultiResponse: Decodable, Sendable {
    let page: Int?
    let results: [TMDBSearchMultiResult]
    let totalPages: Int?
    let totalResults: Int?
}

struct TMDBSearchMultiResult: Decodable, Hashable, Sendable, Identifiable {
    let id: Int
    let mediaType: String?
    let title: String?
    let name: String?
    let overview: String?
    let posterPath: String?
    let releaseDate: String?
    let firstAirDate: String?
    let genreIds: [Int]?
    let voteAverage: Double?

    var resolvedMediaType: MediaType? {
        guard let mediaType else { return nil }
        return MediaType(rawValue: mediaType)
    }

    var displayTitle: String { title ?? name ?? "—" }

    var year: String {
        let raw = releaseDate ?? firstAirDate ?? ""
        return String(raw.prefix(4))
    }
}

struct TMDBMovieDetails: Decodable, Sendable {
    let id: Int
    let title: String
    let overview: String?
    let releaseDate: String?
    let posterPath: String?
    let genres: [TMDBGenre]
    let voteAverage: Double?

    var year: String { String((releaseDate ?? "").prefix(4)) }
}

struct TMDBTVDetails: Decodable, Sendable {
    let id: Int
    let name: String
    let overview: String?
    let firstAirDate: String?
    let posterPath: String?
    let genres: [TMDBGenre]
    let voteAverage: Double?
    let nextEpisodeToAir: TMDBEpisode?
    let seasons: [TMDBSeason]?
    let numberOfSeasons: Int?
    let inProduction: Bool?

    var year: String { String((firstAirDate ?? "").prefix(4)) }
}

struct TMDBEpisode: Decodable, Hashable, Sendable {
    let id: Int?
    let name: String?
    let airDate: String?
    let episodeNumber: Int?
    let seasonNumber: Int?

    var airDateValue: Date? {
        guard let airDate else { return nil }
        return TMDB.dateFormatter.date(from: airDate)
    }
}

struct TMDBSeason: Decodable, Hashable, Sendable {
    let id: Int?
    let name: String?
    let airDate: String?
    let episodeCount: Int?
    let seasonNumber: Int?
    let posterPath: String?
}

struct TMDBRecommendationsResponse: Decodable, Sendable {
    let page: Int?
    let results: [TMDBRecommendation]
}

struct TMDBRecommendation: Decodable, Hashable, Sendable, Identifiable {
    let id: Int
    let mediaType: String?
    let title: String?
    let name: String?
    let overview: String?
    let posterPath: String?
    let releaseDate: String?
    let firstAirDate: String?
    let genreIds: [Int]?
    let voteAverage: Double?

    var displayTitle: String { title ?? name ?? "—" }

    var year: String {
        let raw = releaseDate ?? firstAirDate ?? ""
        return String(raw.prefix(4))
    }
}

enum TMDB {
    static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .iso8601)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(secondsFromGMT: 0)
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static func posterURL(_ path: String?, size: String = "w500") -> URL? {
        guard let path, !path.isEmpty else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/\(size)\(path)")
    }
}
