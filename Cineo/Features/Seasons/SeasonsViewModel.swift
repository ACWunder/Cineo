import Foundation

@MainActor
@Observable
final class SeasonsViewModel {

    struct SeriesStatus: Identifiable, Hashable {
        let item: LibraryItem
        let next: TMDBEpisode?

        var id: Int { item.tmdbId }
        var hasUpcoming: Bool { (next?.airDateValue) != nil }
    }

    enum Visibility: String, CaseIterable, Identifiable, Sendable {
        case active        // hide muted shows
        case all           // show everything, mute-flag visible

        var id: String { rawValue }
        var label: String {
            switch self {
            case .active: "Aktive Serien"
            case .all:    "Mit ausgeblendeten"
            }
        }
    }

    var upcoming: [SeriesStatus] = []
    var isLoading: Bool = false
    var error: String?

    /// Persisted across launches via UserDefaults. Cross-device sync would
    /// mean moving this to Firestore — for now local-only keeps it cheap
    /// and instant.
    private(set) var hiddenIds: Set<Int> = SeasonsViewModel.loadHidden()
    var visibility: Visibility = .active

    private let client = TMDBClient.shared
    private static let storageKey = "Cineo.seasonsHiddenIds"

    // MARK: - Filtered views

    /// Upcoming rows the user should see right now, post-mute filter.
    var visibleUpcoming: [SeriesStatus] {
        switch visibility {
        case .active: return upcoming.filter { !hiddenIds.contains($0.id) }
        case .all:    return upcoming
        }
    }

    func isHidden(_ id: Int) -> Bool { hiddenIds.contains(id) }

    // MARK: - Mute / unmute

    func hide(_ id: Int) {
        guard !hiddenIds.contains(id) else { return }
        hiddenIds.insert(id)
        persist()
    }

    func unhide(_ id: Int) {
        guard hiddenIds.contains(id) else { return }
        hiddenIds.remove(id)
        persist()
    }

    func toggleHidden(_ id: Int) {
        if hiddenIds.contains(id) { unhide(id) } else { hide(id) }
    }

    private func persist() {
        let ints = Array(hiddenIds)
        UserDefaults.standard.set(ints, forKey: Self.storageKey)
    }

    private static func loadHidden() -> Set<Int> {
        let ints = UserDefaults.standard.array(forKey: storageKey) as? [Int] ?? []
        return Set(ints)
    }

    // MARK: - Reload

    func reload(library: [LibraryItem]) async {
        isLoading = true
        defer { isLoading = false }
        error = nil

        let series = library.filter { $0.mediaType == .tv }
        guard !series.isEmpty else {
            upcoming = []
            return
        }

        var statuses: [SeriesStatus] = []
        await withTaskGroup(of: SeriesStatus.self) { group in
            for item in series {
                group.addTask { [client] in
                    do {
                        let details = try await client.tvDetails(item.tmdbId)
                        return SeriesStatus(item: item, next: details.nextEpisodeToAir)
                    } catch {
                        return SeriesStatus(item: item, next: nil)
                    }
                }
            }
            for await result in group { statuses.append(result) }
        }

        // Only series with an announced next episode end up in the deck —
        // dormant shows live in the Bibliothek view, no point duplicating.
        let withDates = statuses.filter { $0.hasUpcoming }
        upcoming = withDates.sorted { (a, b) -> Bool in
            let da = a.next?.airDateValue ?? Date.distantFuture
            let db = b.next?.airDateValue ?? Date.distantFuture
            return da < db
        }

        // Library may have shed items since last hide — keep the muted set
        // tidy by dropping ids that no longer correspond to anything.
        let liveIds = Set(series.map(\.tmdbId))
        let stale = hiddenIds.subtracting(liveIds)
        if !stale.isEmpty {
            hiddenIds.subtract(stale)
            persist()
        }
    }
}
