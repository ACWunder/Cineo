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
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return [] }

        // Multi-word queries get an extra person-search pass: when someone
        // types a full actor name ("Leonardo DiCaprio"), we want their
        // filmography to lead the result list. Single-word queries skip
        // the extra call to keep latency down.
        let looksLikeName = trimmed.split(whereSeparator: { $0.isWhitespace }).count >= 2

        async let multiTask: TMDBSearchMultiResponse = get(
            path: "/search/multi",
            query: ["query": trimmed, "include_adult": "false", "language": "de-DE", "page": "1"]
        )
        async let personTask: TMDBPersonSearchResponse? = lookupPerson(query: trimmed, enabled: looksLikeName)

        let multi = (try await multiTask).results.filter { $0.resolvedMediaType != nil }

        // Hoist the actor's films/shows to the top when their name matches
        // closely (Levenshtein ≤ 2 absorbs the occasional typo).
        if looksLikeName,
           let top = await personTask?.results.first,
           Self.isStrongNameMatch(query: trimmed, name: top.name)
        {
            let credits: TMDBCombinedCreditsResponse? = try? await get(
                path: "/person/\(top.id)/combined_credits",
                query: ["language": "de-DE"]
            )
            if let cast = credits?.cast {
                // Two passes: filter to real roles (drop guest spots on TV
                // where they only appear in 1–2 episodes — those crowd out
                // the actor's actual films), then films first sorted by
                // popularity, then shows by popularity. That way the top
                // result is always the actor's most popular movie.
                let filtered: [TMDBCombinedCredit] = cast.filter { credit in
                    let hasPoster = !(credit.posterPath ?? "").isEmpty
                    let isMovie = credit.mediaType == "movie"
                    let isShow = credit.mediaType == "tv"
                    guard hasPoster, isMovie || isShow else { return false }
                    if isShow, let eps = credit.episodeCount, eps < 3 { return false }
                    return true
                }
                var movies: [TMDBCombinedCredit] = filtered.filter { $0.mediaType == "movie" }
                var shows: [TMDBCombinedCredit] = filtered.filter { $0.mediaType == "tv" }
                movies.sort { ($0.popularity ?? 0) > ($1.popularity ?? 0) }
                shows.sort { ($0.popularity ?? 0) > ($1.popularity ?? 0) }
                let ordered = (movies + shows).prefix(40)
                let creditResults: [TMDBSearchMultiResult] = ordered.map { $0.toMultiResult() }
                let ids: Set<Int> = Set(creditResults.map { $0.id })
                let rest = multi.filter { !ids.contains($0.id) }
                return creditResults + rest
            }
        }

        return multi
    }

    private func lookupPerson(query: String, enabled: Bool) async -> TMDBPersonSearchResponse? {
        guard enabled else { return nil }
        return try? await get(
            path: "/search/person",
            query: ["query": query, "include_adult": "false", "language": "de-DE", "page": "1"]
        )
    }

    private nonisolated static func isStrongNameMatch(query: String, name: String) -> Bool {
        let q = query.lowercased()
        let n = name.lowercased()
        if n == q { return true }
        if n.contains(q) || q.contains(n) { return true }
        return levenshtein(q, n) <= 2
    }

    private nonisolated static func levenshtein(_ a: String, _ b: String) -> Int {
        let aa = Array(a)
        let bb = Array(b)
        if aa.isEmpty { return bb.count }
        if bb.isEmpty { return aa.count }
        var prev = Array(0...bb.count)
        var curr = Array(repeating: 0, count: bb.count + 1)
        for i in 1...aa.count {
            curr[0] = i
            for j in 1...bb.count {
                let cost = aa[i-1] == bb[j-1] ? 0 : 1
                curr[j] = Swift.min(curr[j-1] + 1, prev[j] + 1, prev[j-1] + cost)
            }
            swap(&prev, &curr)
        }
        return prev[bb.count]
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

    func recommendations(for id: Int, mediaType: MediaType, page: Int = 1) async throws -> [TMDBRecommendation] {
        let path = mediaType == .movie ? "/movie/\(id)/recommendations" : "/tv/\(id)/recommendations"
        let res: TMDBRecommendationsResponse = try await get(path: path, query: ["language": "de-DE", "page": String(page)])
        return res.results
    }

    func similar(for id: Int, mediaType: MediaType, page: Int = 1) async throws -> [TMDBRecommendation] {
        let path = mediaType == .movie ? "/movie/\(id)/similar" : "/tv/\(id)/similar"
        let res: TMDBRecommendationsResponse = try await get(path: path, query: ["language": "de-DE", "page": String(page)])
        return res.results
    }

    func trending(page: Int = 1) async throws -> [TMDBSearchMultiResult] {
        let res: TMDBSearchMultiResponse = try await get(path: "/trending/all/week", query: ["language": "de-DE", "page": String(page)])
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
        // Subscription flat-rate only — rent / buy / ad-supported listings tend
        // to be obscure regional providers users don't recognise.
        let pool = region.flatrate ?? []

        // Brand buckets. TMDB ships multiple listings per service ("Netflix",
        // "Netflix Standard with Ads", "Netflix Kids", "WOW", "WOW by Prime
        // Video" …) — we collapse them all into one logo per brand. The
        // bucket order also determines display order in the row.
        let brands: [(brand: String, needles: [String])] = [
            ("Netflix",     ["netflix"]),
            ("Prime Video", ["prime video"]),
            ("Disney+",     ["disney"]),
            ("Apple TV+",   ["apple tv"]),
            ("Paramount+",  ["paramount"]),
            ("WOW",         ["wow"]),
            ("Sky",         ["sky go", "sky x"]),
            ("RTL+",        ["rtl+", "rtl plus"]),
            ("Joyn",        ["joyn"])
        ]

        // Hard exclusions — variants we never want, regardless of which brand
        // they'd otherwise belong to. Handles ad tiers, kids tiers and
        // Amazon's resold sub-channels in one pass.
        let excludeMarkers = [
            "with ads",
            "ad-supported",
            "amazon channel",
            "by prime video",
            "kids"
        ]

        func brandFor(_ name: String) -> String? {
            let lower = name.lowercased()
            for marker in excludeMarkers where lower.contains(marker) { return nil }
            for entry in brands {
                if entry.needles.contains(where: { lower.contains($0) }) {
                    return entry.brand
                }
            }
            return nil
        }

        let sorted = pool
            .filter { $0.logoPath != nil }
            .sorted(by: { ($0.displayPriority ?? Int.max) < ($1.displayPriority ?? Int.max) })

        var seenBrands = Set<String>()
        var result: [DetailExtras.Provider] = []
        for p in sorted {
            guard let brand = brandFor(p.providerName), !seenBrands.contains(brand) else { continue }
            seenBrands.insert(brand)
            result.append(DetailExtras.Provider(
                id: p.providerId,
                name: p.providerName,
                logoPath: p.logoPath
            ))
        }
        return result
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
