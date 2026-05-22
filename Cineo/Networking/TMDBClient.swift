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

private enum AnyCachedDetail {
    case movie(TMDBMovieDetails)
    case tv(TMDBTVDetails)

    var movie: TMDBMovieDetails? {
        if case .movie(let m) = self { return m }; return nil
    }
    var tv: TMDBTVDetails? {
        if case .tv(let t) = self { return t }; return nil
    }
}
