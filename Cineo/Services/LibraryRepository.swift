import Foundation
import FirebaseFirestore

@MainActor
@Observable
final class LibraryRepository {

    private(set) var items: [LibraryItem] = []
    private(set) var isLoading: Bool = false
    /// Becomes true once the snapshot listener has delivered its first
    /// callback — i.e. items now reflects what's actually in Firestore.
    /// Used by DiscoverView to avoid showing candidates that are already
    /// in the library before the first snapshot arrives.
    private(set) var hasLoadedInitial: Bool = false
    private(set) var lastError: String?

    private var listener: ListenerRegistration?
    private var uid: String?
    private let db = Firestore.firestore()

    func start(uid: String) {
        guard self.uid != uid else { return }
        stop()
        self.uid = uid
        isLoading = true
        hasLoadedInitial = false
        let ref = db.collection("users").document(uid).collection("library")
        listener = ref.addSnapshotListener { [weak self] snapshot, error in
            Task { @MainActor in
                guard let self else { return }
                self.isLoading = false
                self.hasLoadedInitial = true
                if let error {
                    self.lastError = error.localizedDescription
                    return
                }
                guard let snapshot else { return }
                self.items = snapshot.documents.compactMap { Self.decode($0.data()) }
                    .sorted(by: { $0.addedAt > $1.addedAt })
                // Warm the URL cache so the first filter switch (which
                // brings previously off-screen cells into view) doesn't
                // pay the network/decode tax. Idempotent against
                // already-cached entries.
                self.prefetchPosters()
            }
        }
    }

    /// Warms `PosterImageCache` with fully-decoded library posters so the
    /// first scroll / filter / search after a cold start doesn't stutter
    /// while every cell synchronously decodes its JPEG on the main
    /// thread. Bounded concurrency (6 in flight) keeps the CPU from
    /// spiking on launch.
    private func prefetchPosters() {
        let urls = items.prefix(80).compactMap {
            TMDB.posterURL($0.posterPath, size: "w342")
        }
        guard !urls.isEmpty else { return }
        Task.detached(priority: .utility) {
            await withTaskGroup(of: Void.self) { group in
                let maxConcurrent = 6
                var nextIndex = 0
                let inFlight = min(maxConcurrent, urls.count)
                for _ in 0..<inFlight {
                    let url = urls[nextIndex]
                    nextIndex += 1
                    group.addTask { await PosterImageCache.shared.prefetch(url) }
                }
                while await group.next() != nil {
                    if nextIndex < urls.count {
                        let url = urls[nextIndex]
                        nextIndex += 1
                        group.addTask { await PosterImageCache.shared.prefetch(url) }
                    }
                }
            }
        }
    }

    func stop() {
        listener?.remove()
        listener = nil
        uid = nil
        items = []
        hasLoadedInitial = false
    }

    // MARK: - Mutations

    func add(_ item: LibraryItem) async {
        guard let uid else { return }
        let ref = db.collection("users").document(uid).collection("library").document(String(item.tmdbId))
        do {
            try await ref.setData(Self.encode(item), merge: false)
        } catch {
            lastError = error.localizedDescription
        }
    }

    /// Only updates the rating. Leaves `watched` untouched (used by the
    /// LibraryDetailView slider, where the item is already watched).
    func updateRating(tmdbId: Int, rating: Double?) async {
        guard let uid else { return }
        let ref = db.collection("users").document(uid).collection("library").document(String(tmdbId))
        var data: [String: Any] = [:]
        if let rating { data["rating"] = rating } else { data["rating"] = FieldValue.delete() }
        do {
            try await ref.updateData(data)
        } catch {
            lastError = error.localizedDescription
        }
    }

    /// Promotes a watchlist item into the library: sets `watched = true` and
    /// applies the rating (or removes it on skip). Atomic update.
    func markWatched(tmdbId: Int, rating: Double?) async {
        guard let uid else { return }
        let ref = db.collection("users").document(uid).collection("library").document(String(tmdbId))
        var data: [String: Any] = ["watched": true]
        if let rating { data["rating"] = rating } else { data["rating"] = FieldValue.delete() }
        do {
            try await ref.updateData(data)
        } catch {
            lastError = error.localizedDescription
        }
    }

    func setWatched(tmdbId: Int, watched: Bool) async {
        guard let uid else { return }
        let ref = db.collection("users").document(uid).collection("library").document(String(tmdbId))
        do {
            try await ref.updateData(["watched": watched])
        } catch {
            lastError = error.localizedDescription
        }
    }

    func remove(tmdbId: Int) async {
        guard let uid else { return }
        let ref = db.collection("users").document(uid).collection("library").document(String(tmdbId))
        do {
            try await ref.delete()
        } catch {
            lastError = error.localizedDescription
        }
    }

    func contains(tmdbId: Int) -> Bool {
        items.contains(where: { $0.tmdbId == tmdbId })
    }

    // MARK: - Codec

    static func encode(_ item: LibraryItem) -> [String: Any] {
        var data: [String: Any] = [
            "tmdbId": item.tmdbId,
            "mediaType": item.mediaType.rawValue,
            "title": item.title,
            "overview": item.overview,
            "year": item.year,
            "genres": item.genres,
            "watched": item.watched,
            "addedAt": Timestamp(date: item.addedAt)
        ]
        if let posterPath = item.posterPath { data["posterPath"] = posterPath }
        if let rating = item.rating { data["rating"] = rating }
        return data
    }

    static func decode(_ data: [String: Any]) -> LibraryItem? {
        guard
            let tmdbId = data["tmdbId"] as? Int,
            let mediaTypeRaw = data["mediaType"] as? String,
            let mediaType = MediaType(rawValue: mediaTypeRaw),
            let title = data["title"] as? String
        else { return nil }

        let overview = data["overview"] as? String ?? ""
        let year = data["year"] as? String ?? ""
        let posterPath = data["posterPath"] as? String
        let genres = data["genres"] as? [String] ?? []
        // Rating is now a Double (0.5 steps). Old documents stored Int — accept both.
        let rating: Double? = {
            if let d = data["rating"] as? Double { return d }
            if let i = data["rating"] as? Int { return Double(i) }
            if let n = data["rating"] as? NSNumber { return n.doubleValue }
            return nil
        }()
        let watched = data["watched"] as? Bool ?? false
        let addedAt = (data["addedAt"] as? Timestamp)?.dateValue() ?? Date()

        return LibraryItem(
            tmdbId: tmdbId,
            mediaType: mediaType,
            title: title,
            overview: overview,
            year: year,
            posterPath: posterPath,
            genres: genres,
            rating: rating,
            watched: watched,
            addedAt: addedAt
        )
    }
}
