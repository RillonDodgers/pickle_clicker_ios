import Combine
import Foundation
import OSLog

@MainActor
final class DanbooruPostDetailViewModel: ObservableObject {
    @Published private(set) var post: DanbooruPostCardState?
    @Published private(set) var comments: [DanbooruComment] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?
    @Published private(set) var usernamesByID: [Int: String] = [:]
    @Published private(set) var originalPosterID: Int?
    private let userDirectory = DanbooruUserDirectory.shared
    private let interactionStore = DanbooruPostInteractionStore.shared

    func load(postID: Int, configuration: DanbooruClientConfiguration?, commentSortOrder: DanbooruCommentSortOrder) async {
        DanbooruDiagnostics.ui.info("PostDetail load start postID=\(postID, privacy: .public)")
        guard let configuration else {
            errorMessage = DanbooruAPIError.invalidConfiguration.localizedDescription
            return
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let client = DanbooruAPIClient(configuration: configuration)
            async let postRequest = client.fetchPost(id: postID)
            async let commentsRequest = client.fetchComments(postID: postID)
            let (fetchedPost, fetchedComments) = try await (postRequest, commentsRequest)
            var mappedPost = DanbooruPostCardState(post: fetchedPost)
            if let snapshot = await interactionStore.interactionMap(
                host: configuration.baseURL.absoluteString,
                login: configuration.login,
                postIDs: [postID]
            )[postID] {
                mappedPost.applyPersistedInteraction(snapshot)
            }
            post = mappedPost
            usernamesByID = [:]
            originalPosterID = fetchedPost.uploaderID
            comments = sortComments(fetchedComments, order: commentSortOrder)

            for comment in fetchedComments {
                if let creatorID = comment.creatorID, usernamesByID[creatorID] == nil {
                    if let creatorName = comment.creatorName, !creatorName.isEmpty {
                        usernamesByID[creatorID] = creatorName
                        await userDirectory.storeUsername(host: configuration.baseURL.absoluteString, userID: creatorID, username: creatorName)
                    } else if let cachedName = await userDirectory.cachedUsername(host: configuration.baseURL.absoluteString, userID: creatorID) {
                        usernamesByID[creatorID] = cachedName
                    } else if let fetchedUser = try? await client.fetchUser(id: creatorID) {
                        usernamesByID[creatorID] = fetchedUser.name
                        await userDirectory.storeUsername(host: configuration.baseURL.absoluteString, userID: creatorID, username: fetchedUser.name)
                    }
                }
            }
            DanbooruDiagnostics.ui.info("PostDetail load success postID=\(postID, privacy: .public) comments=\(fetchedComments.count, privacy: .public)")
        } catch {
            if isAsyncCancellationError(error) {
                DanbooruDiagnostics.ui.info("PostDetail load cancelled postID=\(postID, privacy: .public)")
                errorMessage = nil
                return
            }
            DanbooruDiagnostics.ui.error("PostDetail load failed postID=\(postID, privacy: .public) error=\(error.localizedDescription, privacy: .public)")
            errorMessage = error.localizedDescription
        }
    }

    func displayName(for comment: DanbooruComment) -> String {
        if let creatorID = comment.creatorID, let cachedName = usernamesByID[creatorID] {
            return cachedName
        }

        if let creatorName = comment.creatorName, !creatorName.isEmpty {
            return creatorName
        }

        return "Unknown"
    }

    func isOriginalPoster(_ comment: DanbooruComment) -> Bool {
        guard let creatorID = comment.creatorID, let originalPosterID else { return false }
        return creatorID == originalPosterID
    }

    private func sortComments(_ comments: [DanbooruComment], order: DanbooruCommentSortOrder) -> [DanbooruComment] {
        comments.sorted { lhs, rhs in
            let lhsDate = lhs.createdAt ?? .distantPast
            let rhsDate = rhs.createdAt ?? .distantPast
            switch order {
            case .oldestFirst:
                return lhsDate < rhsDate
            case .newestFirst:
                return lhsDate > rhsDate
            }
        }
    }
}
