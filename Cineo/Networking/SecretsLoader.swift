import Foundation

nonisolated enum Secrets {

    /// TMDB v4 Read Access Token (Bearer). Loaded from Info.plist key `TMDBBearerToken`,
    /// which is wired to `$(TMDB_BEARER_TOKEN)` from `Config/Secrets.xcconfig`.
    static var tmdbBearerToken: String? {
        guard
            let raw = Bundle.main.object(forInfoDictionaryKey: "TMDBBearerToken") as? String,
            !raw.isEmpty,
            raw != "REPLACE_WITH_YOUR_TMDB_V4_BEARER_TOKEN"
        else {
            return nil
        }
        return raw
    }

    static var tmdbBearerTokenOrCrash: String {
        guard let token = tmdbBearerToken else {
            assertionFailure("TMDBBearerToken missing. Fill Config/Secrets.xcconfig.")
            return ""
        }
        return token
    }
}
