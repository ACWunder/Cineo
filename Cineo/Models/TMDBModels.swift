import Foundation

nonisolated struct TMDBGenre: Decodable, Hashable, Sendable {
    let id: Int
    let name: String
}

nonisolated struct TMDBGenresResponse: Decodable, Sendable {
    let genres: [TMDBGenre]
}

nonisolated struct TMDBSearchMultiResponse: Decodable, Sendable {
    let page: Int?
    let results: [TMDBSearchMultiResult]
    let totalPages: Int?
    let totalResults: Int?
}

nonisolated struct TMDBSearchMultiResult: Decodable, Hashable, Sendable, Identifiable {
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

nonisolated struct TMDBMovieDetails: Decodable, Sendable {
    let id: Int
    let title: String
    let overview: String?
    let releaseDate: String?
    let posterPath: String?
    let backdropPath: String?
    let tagline: String?
    let runtime: Int?
    let status: String?
    let genres: [TMDBGenre]
    let voteAverage: Double?

    var year: String { String((releaseDate ?? "").prefix(4)) }
}

nonisolated struct TMDBTVDetails: Decodable, Sendable {
    let id: Int
    let name: String
    let overview: String?
    let firstAirDate: String?
    let posterPath: String?
    let backdropPath: String?
    let tagline: String?
    let episodeRunTime: [Int]?
    let status: String?
    let genres: [TMDBGenre]
    let voteAverage: Double?
    let nextEpisodeToAir: TMDBEpisode?
    let seasons: [TMDBSeason]?
    let numberOfSeasons: Int?
    let inProduction: Bool?

    var year: String { String((firstAirDate ?? "").prefix(4)) }
}

// MARK: - Credits

nonisolated struct TMDBCreditsResponse: Decodable, Sendable {
    let cast: [TMDBCastMember]
}

nonisolated struct TMDBCastMember: Decodable, Hashable, Sendable, Identifiable {
    let id: Int
    let name: String
    let character: String?
    let profilePath: String?
    let order: Int?
}

// MARK: - Videos (trailers)

nonisolated struct TMDBVideosResponse: Decodable, Sendable {
    let results: [TMDBVideo]
}

nonisolated struct TMDBVideo: Decodable, Hashable, Sendable, Identifiable {
    let id: String
    let key: String
    let site: String
    let type: String
    let official: Bool?
    let name: String?
    let publishedAt: String?
}

// MARK: - Watch providers (JustWatch)

nonisolated struct TMDBWatchProvidersResponse: Decodable, Sendable {
    let results: [String: TMDBProviderRegion]
}

nonisolated struct TMDBProviderRegion: Decodable, Sendable {
    let flatrate: [TMDBProvider]?
    let free: [TMDBProvider]?
    let ads: [TMDBProvider]?
    let buy: [TMDBProvider]?
    let rent: [TMDBProvider]?
    let link: String?
}

nonisolated struct TMDBProvider: Decodable, Hashable, Sendable, Identifiable {
    let providerId: Int
    let providerName: String
    let logoPath: String?
    let displayPriority: Int?

    var id: Int { providerId }
}

nonisolated struct TMDBEpisode: Decodable, Hashable, Sendable {
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

nonisolated struct TMDBSeason: Decodable, Hashable, Sendable {
    let id: Int?
    let name: String?
    let airDate: String?
    let episodeCount: Int?
    let seasonNumber: Int?
    let posterPath: String?
}

nonisolated struct TMDBRecommendationsResponse: Decodable, Sendable {
    let page: Int?
    let results: [TMDBRecommendation]
}

nonisolated struct TMDBRecommendation: Decodable, Hashable, Sendable, Identifiable {
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

nonisolated enum TMDB {
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

    static func backdropURL(_ path: String?, size: String = "w1280") -> URL? {
        guard let path, !path.isEmpty else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/\(size)\(path)")
    }

    static func profileURL(_ path: String?, size: String = "w185") -> URL? {
        guard let path, !path.isEmpty else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/\(size)\(path)")
    }

    static func providerLogoURL(_ path: String?, size: String = "w92") -> URL? {
        guard let path, !path.isEmpty else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/\(size)\(path)")
    }
}
