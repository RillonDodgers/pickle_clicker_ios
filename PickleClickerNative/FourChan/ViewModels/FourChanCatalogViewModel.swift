import Combine
import Foundation

@MainActor
final class FourChanCatalogViewModel: ObservableObject {
    @Published private(set) var threads: [FourChanPost] = []
    @Published var errorMessage: String?
    @Published private(set) var isLoading = false

    private let client = FourChanAPIClient()

    func ensureLoaded(boardID: String) async {
        guard threads.isEmpty else { return }
        await reload(boardID: boardID)
    }

    func reload(boardID: String) async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            errorMessage = nil
            let fetchedThreads = try await client.fetchCatalog(boardID: boardID)
            threads = fetchedThreads
        } catch {
            if isAsyncCancellationError(error) {
                errorMessage = nil
                return
            }
            errorMessage = error.localizedDescription
        }
    }
}
