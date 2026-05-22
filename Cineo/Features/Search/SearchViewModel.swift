import Foundation

@MainActor
@Observable
final class SearchViewModel {
    var query: String = ""
    var results: [TMDBSearchMultiResult] = []
    var isLoading: Bool = false
    var error: String?

    private let client = TMDBClient.shared

    func search() async {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if q.isEmpty {
            results = []
            error = nil
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            results = try await client.searchMulti(query: q)
            error = nil
        } catch let err as TMDBError {
            error = err.localizedDescription
        } catch let err {
            error = err.localizedDescription
        }
    }
}
