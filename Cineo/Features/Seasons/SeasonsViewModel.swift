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

    var upcoming: [SeriesStatus] = []
    var dormant: [SeriesStatus] = []
    var isLoading: Bool = false
    var error: String?

    private let client = TMDBClient.shared

    func reload(library: [LibraryItem]) async {
        isLoading = true
        defer { isLoading = false }
        error = nil

        let series = library.filter { $0.mediaType == .tv }
        guard !series.isEmpty else {
            upcoming = []
            dormant = []
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

        let withDates = statuses.filter { $0.hasUpcoming }
        let withoutDates = statuses.filter { !$0.hasUpcoming }

        upcoming = withDates.sorted { (a, b) in
            (a.next?.airDateValue ?? .distantFuture) < (b.next?.airDateValue ?? .distantFuture)
        }
        dormant = withoutDates.sorted { $0.item.title.localizedCaseInsensitiveCompare($1.item.title) == .orderedAscending }
    }
}
