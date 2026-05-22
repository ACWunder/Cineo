import Foundation

enum TMDBError: Error, LocalizedError {
    case missingToken
    case badStatus(Int)
    case decoding(Error)
    case transport(Error)

    var errorDescription: String? {
        switch self {
        case .missingToken: "TMDB-Token fehlt. Setze TMDB_BEARER_TOKEN in Config/Secrets.xcconfig."
        case .badStatus(let code): "TMDB hat mit Status \(code) geantwortet."
        case .decoding(let err): "Antwort konnte nicht gelesen werden: \(err.localizedDescription)"
        case .transport(let err): "Netzwerkfehler: \(err.localizedDescription)"
        }
    }
}

actor TMDBClient {

    static let shared = TMDBClient()

    private let session: URLSession
    private let decoder: JSONDecoder
    private let baseURL = URL(string: "https://api.themoviedb.org/3")!

    private var movieGenreCache: [Int: String] = [:]
    private var tvGenreCache: [Int: String] = [:]
    private var genresLoaded = false
    private var detailsCache: [String: AnyCachedDetail] = [:]

    init(session: URLSession = .shared) {
        self.session = session
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        self.decoder = d
    }

    // MARK: - Public API

    func ensureGenresLoaded() async throws {
        guard !genresLoaded else { return }
        async let movie: TMDBGenresResponse = get(path: "/genre/movie/list", query: ["language": "de-DE"])
        async let tv: TMDBGenresResponse = get(path: "/genre/tv/list", query: ["language": "de-DE"])
        let (mv, tvr) = try await (movie, tv)
        for g in mv.genres { movieGenreCache[g.id] = g.name }
        for g in tvr.genres { tvGenreCache[g.id] = g.name }
        genresLoaded = true
    }

    func resolveGenres(ids: [Int]?, mediaType: MediaType) -> [String] {
        guard let ids else { return [] }
        let map = mediaType == .movie ? movieGenreCache : tvGenreCache
        return ids.compactMap { map[$0] }
    }

    func searchMulti(query: String) async throws -> [TMDBSearchMultiResult] {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return [] }
        let response: TMDBSearchMultiResponse = try await get(
            path: "/search/multi",
            query: ["query": query, "include_adult": "false", "language": "de-DE", "page": "1"]
        )
        return response.results.filter { $0.resolvedMediaType != nil }
    }

    func movieDetails(_ id: Int) async throws -> TMDBMovieDetails {
        if let cached = detailsCache["movie-\(id)"]?.movie { return cached }
        let res: TMDBMovieDetails = try await get(path: "/movie/\(id)", query: ["language": "de-DE"])
        detailsCache["movie-\(id)"] = .movie(res)
        return res
    }

    func tvDetails(_ id: Int) async throws -> TMDBTVDetails {
        if let cached = detailsCache["tv-\(id)"]?.tv { return cached }
        let res: TMDBTVDetails = try await get(path: "/tv/\(id)", query: ["language": "de-DE"])
        detailsCache["tv-\(id)"] = .tv(res)
        return res
    }

    func recommendations(for id: Int, mediaType: MediaType) async throws -> [TMDBRecommendation] {
        let path = mediaType == .movie ? "/movie/\(id)/recommendations" : "/tv/\(id)/recommendations"
        let res: TMDBRecommendationsResponse = try await get(path: path, query: ["language": "de-DE", "page": "1"])
        return res.results
    }

    func similar(for id: Int, mediaType: MediaType) async throws -> [TMDBRecommendation] {
        let path = mediaType == .movie ? "/movie/\(id)/similar" : "/tv/\(id)/similar"
        let res: TMDBRecommendationsResponse = try await get(path: path, query: ["language": "de-DE", "page": "1"])
        return res.results
    }

    func trending() async throws -> [TMDBSearchMultiResult] {
        let res: TMDBSearchMultiResponse = try await get(path: "/trending/all/week", query: ["language": "de-DE"])
        return res.results.filter { $0.resolvedMediaType != nil }
    }

    // MARK: - Detail extras (cast / videos / providers / backdrop / runtime)

    /// Loads everything the detail view needs in three parallel calls:
    /// the base details (for backdrop + tagline + runtime), credits, videos
    /// and watch providers. Falls back to neutral defaults on any partial
    /// failure so the screen never refuses to render.
    func extras(for id: Int, mediaType: MediaType, region: String = "DE") async -> DetailExtras {
        switch mediaType {
        case .movie:
            return await loadMovieExtras(id: id, region: region)
        case .tv:
            return await loadTVExtras(id: id, region: region)
        }
    }

    private func loadMovieExtras(id: Int, region: String) async -> DetailExtras {
        async let details = try? await movieDetails(id)
        async let credits: TMDBCreditsResponse? = try? await get(
            path: "/movie/\(id)/credits",
            query: ["language": "de-DE"]
        )
        async let videos: TMDBVideosResponse? = try? await get(
            path: "/movie/\(id)/videos",
            query: ["language": "en-US"]
        )
        async let providers: TMDBWatchProvidersResponse? = try? await get(
            path: "/movie/\(id)/watch/providers",
            query: [:]
        )

        let d = await details
        let c = await credits
        let v = await videos
        let p = await providers

        return DetailExtras(
            backdropPath: d?.backdropPath,
            tagline: d?.tagline,
            runtimeMinutes: d?.runtime,
            cast: Self.mapCast(c?.cast),
            trailerYouTubeKey: Self.pickTrailerKey(v?.results),
            providers: Self.mapProviders(p?.results[region])
        )
    }

    private func loadTVExtras(id: Int, region: String) async -> DetailExtras {
        async let details = try? await tvDetails(id)
        async let credits: TMDBCreditsResponse? = try? await get(
            path: "/tv/\(id)/credits",
            query: ["language": "de-DE"]
        )
        async let videos: TMDBVideosResponse? = try? await get(
            path: "/tv/\(id)/videos",
            query: ["language": "en-US"]
        )
        async let providers: TMDBWatchProvidersResponse? = try? await get(
            path: "/tv/\(id)/watch/providers",
            query: [:]
        )

        let d = await details
        let c = await credits
        let v = await videos
        let p = await providers

        // TV runtime is `episode_run_time: [Int]`. Take the first.
        let runtime = d?.episodeRunTime?.first

        return DetailExtras(
            backdropPath: d?.backdropPath,
            tagline: d?.tagline,
            runtimeMinutes: runtime,
            cast: Self.mapCast(c?.cast),
            trailerYouTubeKey: Self.pickTrailerKey(v?.results),
            providers: Self.mapProviders(p?.results[region])
        )
    }

    private nonisolated static func mapCast(_ cast: [TMDBCastMember]?) -> [DetailExtras.CastMember] {
        guard let cast else { return [] }
        return cast
            .sorted(by: { ($0.order ?? Int.max) < ($1.order ?? Int.max) })
            .prefix(6)
            .map {
                DetailExtras.CastMember(
                    id: $0.id,
                    name: $0.name,
                    character: $0.character,
                    profilePath: $0.profilePath
                )
            }
    }

    /// Prefers official YouTube trailers; falls back to any YouTube trailer.
    private nonisolated static func pickTrailerKey(_ videos: [TMDBVideo]?) -> String? {
        guard let videos else { return nil }
        let youtubeTrailers = videos.filter { $0.site == "YouTube" && $0.type == "Trailer" }
        if let official = youtubeTrailers.first(where: { $0.official == true }) {
            return official.key
        }
        return youtubeTrailers.first?.key
    }

    private nonisolated static func mapProviders(_ region: TMDBProviderRegion?) -> [DetailExtras.Provider] {
        guard let region else { return [] }
        // Prefer flatrate (subscription) — that's the most relevant for "where
        // can I stream this?". Falls back to free, then ads, then rent / buy.
        let pool = region.flatrate ?? region.free ?? region.ads ?? region.rent ?? region.buy ?? []
        return pool
            .sorted(by: { ($0.displayPriority ?? Int.max) < ($1.displayPriority ?? Int.max) })
            .prefix(6)
            .map {
                DetailExtras.Provider(
                    id: $0.providerId,
                    name: $0.providerName,
                    logoPath: $0.logoPath
                )
            }
    }

    // MARK: - Generic GET

    private func get<T: Decodable>(path: String, query: [String: String] = [:]) async throws -> T {
        guard let token = Secrets.tmdbBearerToken else { throw TMDBError.missingToken }

        var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        if !query.isEmpty {
            components.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        var request = URLRequest(url: components.url!)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json;charset=utf-8", forHTTPHeaderField: "Accept")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw TMDBError.transport(error)
        }

        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw TMDBError.badStatus(http.statusCode)
        }
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw TMDBError.decoding(error)
        }
    }
}

private nonisolated enum AnyCachedDetail {
    case movie(TMDBMovieDetails)
    case tv(TMDBTVDetails)

    var movie: TMDBMovieDetails? {
        if case .movie(let m) = self { return m }; return nil
    }
    var tv: TMDBTVDetails? {
        if case .tv(let t) = self { return t }; return nil
    }
}
