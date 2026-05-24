import Foundation
import FirebaseFirestore

@MainActor
@Observable
final class DismissedRepository {

    private(set) var items: [DismissedItem] = []
    private(set) var hasLoadedInitial: Bool = false
    private(set) var lastError: String?

    private var listener: ListenerRegistration?
    private var uid: String?
    private let db = Firestore.firestore()

    func start(uid: String) {
        guard self.uid != uid else { return }
        stop()
        self.uid = uid
        hasLoadedInitial = false
        let ref = db.collection("users").document(uid).collection("dismissed")
        listener = ref.addSnapshotListener { [weak self] snapshot, error in
            Task { @MainActor in
                guard let self else { return }
                self.hasLoadedInitial = true
                if let error { self.lastError = error.localizedDescription; return }
                guard let snapshot else { return }
                self.items = snapshot.documents.compactMap { Self.decode($0.data()) }
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

    func dismiss(tmdbId: Int, mediaType: MediaType) async {
        guard let uid else { return }
        let ref = db.collection("users").document(uid).collection("dismissed").document(String(tmdbId))
        do {
            try await ref.setData([
                "tmdbId": tmdbId,
                "mediaType": mediaType.rawValue,
                "dismissedAt": Timestamp(date: Date())
            ])
        } catch {
            lastError = error.localizedDescription
        }
    }

    func undismiss(tmdbId: Int) async {
        guard let uid else { return }
        let ref = db.collection("users").document(uid).collection("dismissed").document(String(tmdbId))
        do {
            try await ref.delete()
        } catch {
            lastError = error.localizedDescription
        }
    }

    func contains(tmdbId: Int) -> Bool {
        items.contains(where: { $0.tmdbId == tmdbId })
    }

    static func decode(_ data: [String: Any]) -> DismissedItem? {
        guard
            let tmdbId = data["tmdbId"] as? Int,
            let mediaTypeRaw = data["mediaType"] as? String,
            let mediaType = MediaType(rawValue: mediaTypeRaw)
        else { return nil }
        let dismissedAt = (data["dismissedAt"] as? Timestamp)?.dateValue()
        return DismissedItem(tmdbId: tmdbId, mediaType: mediaType, dismissedAt: dismissedAt)
    }
}
