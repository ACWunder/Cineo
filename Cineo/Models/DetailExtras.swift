import Foundation

/// View-facing bundle of "everything beyond the basic poster+title" that
/// the LibraryDetailView shows. Assembled from the TMDB endpoints
/// `/credits`, `/videos` and `/watch/providers`, plus a few fields from
/// the main details payload.
nonisolated struct DetailExtras: Sendable {
    let backdropPath: String?
    let tagline: String?
    let runtimeMinutes: Int?
    let cast: [CastMember]
    let trailerYouTubeKey: String?
    let providers: [Provider]

    struct CastMember: Identifiable, Hashable, Sendable {
        let id: Int
        let name: String
        let character: String?
        let profilePath: String?
    }

    struct Provider: Identifiable, Hashable, Sendable {
        let id: Int
        let name: String
        let logoPath: String?
    }
}
