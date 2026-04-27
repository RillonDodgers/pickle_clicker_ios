import Combine
import Foundation

@MainActor
final class FourChanThreadViewModel: ObservableObject {
    @Published private(set) var posts: [FourChanPost] = []
    @Published var errorMessage: String?
    @Published private(set) var isLoading = false

    private let client = FourChanAPIClient()

    func ensureLoaded(boardID: String, threadID: Int) async {
        guard posts.isEmpty else { return }
        await reload(boardID: boardID, threadID: threadID)
    }

    func reload(boardID: String, threadID: Int) async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            errorMessage = nil
            let fetchedPosts = try await client.fetchThread(boardID: boardID, threadID: threadID)
            posts = fetchedPosts
        } catch {
            if isAsyncCancellationError(error) {
                errorMessage = nil
                return
            }
            errorMessage = error.localizedDescription
        }
    }
}
