import Foundation
import FirebaseFirestore

@MainActor
@Observable
final class LibraryRepository {

    private(set) var items: [LibraryItem] = []
    private(set) var isLoading: Bool = false
    private(set) var lastError: String?

    private var listener: ListenerRegistration?
    private var uid: String?
    private let db = Firestore.firestore()

    func start(uid: String) {
        guard self.uid != uid else { return }
        stop()
        self.uid = uid
        isLoading = true
        let ref = db.collection("users").document(uid).collection("library")
        listener = ref.addSnapshotListener { [weak self] snapshot, error in
            Task { @MainActor in
                guard let self else { return }
                self.isLoading = false
                if let error {
                    self.lastError = error.localizedDescription
                    return
                }
                guard let snapshot else { return }
                self.items = snapshot.documents.compactMap { Self.decode($0.data()) }
                    .sorted(by: { $0.addedAt > $1.addedAt })
            }
        }
    }

    func stop() {
        listener?.remove()
        listener = nil
        uid = nil
        items = []
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

    func updateRating(tmdbId: Int, rating: Int?) async {
        guard let uid else { return }
        let ref = db.collection("users").document(uid).collection("library").document(String(tmdbId))
        var data: [String: Any] = ["watched": rating != nil]
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
        let rating = data["rating"] as? Int
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
