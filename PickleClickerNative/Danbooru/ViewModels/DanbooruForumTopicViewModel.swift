import Combine
import Foundation
import OSLog

@MainActor
final class DanbooruForumTopicViewModel: ObservableObject {
    @Published private(set) var posts: [DanbooruForumPost] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?
    @Published private(set) var usernamesByID: [Int: String] = [:]
    private let userDirectory = DanbooruUserDirectory.shared

    func load(topicID: Int, configuration: DanbooruClientConfiguration?, commentSortOrder: DanbooruCommentSortOrder, topicCreatorID: Int?) async {
        DanbooruDiagnostics.ui.info("ForumTopic load start topicID=\(topicID, privacy: .public)")
        guard let configuration else {
            errorMessage = DanbooruAPIError.invalidConfiguration.localizedDescription
            return
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let client = DanbooruAPIClient(configuration: configuration)
            let fetchedPosts = try await client.fetchForumPosts(topicID: topicID)
            usernamesByID = [:]
            posts = fetchedPosts
                .filter { !$0.isDeleted }
                .sorted { lhs, rhs in
                    let lhsDate = lhs.createdAt ?? .distantPast
                    let rhsDate = rhs.createdAt ?? .distantPast
                    switch commentSortOrder {
                    case .oldestFirst:
                        return lhsDate < rhsDate
                    case .newestFirst:
                        return lhsDate > rhsDate
                    }
                }

            for post in posts {
                if let creatorID = post.creatorID, usernamesByID[creatorID] == nil {
                    if let cachedName = await userDirectory.cachedUsername(host: configuration.baseURL.absoluteString, userID: creatorID) {
                        usernamesByID[creatorID] = cachedName
                    } else if let fetchedUser = try? await client.fetchUser(id: creatorID) {
                        usernamesByID[creatorID] = fetchedUser.name
                        await userDirectory.storeUsername(host: configuration.baseURL.absoluteString, userID: creatorID, username: fetchedUser.name)
                    }
                }
            }

            DanbooruDiagnostics.ui.info("ForumTopic load success topicID=\(topicID, privacy: .public) count=\(self.posts.count, privacy: .public)")
        } catch {
            if isAsyncCancellationError(error) {
                DanbooruDiagnostics.ui.info("ForumTopic load cancelled topicID=\(topicID, privacy: .public)")
                errorMessage = nil
                return
            }
            DanbooruDiagnostics.ui.error("ForumTopic load failed topicID=\(topicID, privacy: .public) error=\(error.localizedDescription, privacy: .public)")
            errorMessage = error.localizedDescription
        }
    }

    func displayName(for userID: Int?) -> String {
        guard let userID else { return "Unknown" }
        return usernamesByID[userID] ?? "User #\(userID)"
    }

    func isTopicCreator(_ userID: Int?, topicCreatorID: Int?) -> Bool {
        guard let userID, let topicCreatorID else { return false }
        return userID == topicCreatorID
    }
}
