import Combine
import Foundation
import OSLog

@MainActor
final class DanbooruProfileViewModel: ObservableObject {
    @Published private(set) var user: DanbooruUser?
    @Published private(set) var favoritePosts: [DanbooruPostCardState] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?
    private let interactionStore = DanbooruPostInteractionStore.shared

    func reload(target: DanbooruProfileTarget, using configuration: DanbooruClientConfiguration?) async {
        DanbooruDiagnostics.ui.info("Profile reload start")
        errorMessage = nil

        guard let configuration else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            let client = DanbooruAPIClient(configuration: configuration)
            let fetchedUser: DanbooruUser
            switch target {
            case .currentUser:
                fetchedUser = try await client.fetchCurrentUser()
            case let .user(id, _):
                fetchedUser = try await client.fetchUser(id: id)
            }
            user = fetchedUser

            let favoriteRecords = try await client.fetchFavorites(userID: fetchedUser.id)
            let favoritePostIDs = Array(NSOrderedSet(array: favoriteRecords.map(\.postID))) as? [Int] ?? favoriteRecords.map(\.postID)
            let mappedFavorites = try await withThrowingTaskGroup(of: (Int, DanbooruPostCardState?, DanbooruPost?).self) { group in
                for postID in favoritePostIDs {
                    group.addTask {
                        let post = try await client.fetchPost(id: postID)
                        return (postID, nil, post)
                    }
                }

                var postsByID: [Int: DanbooruPostCardState] = [:]
                for try await (postID, cachedPost, fetchedPost) in group {
                    if let cachedPost {
                        postsByID[postID] = cachedPost
                    } else if let fetchedPost, !(fetchedPost.isPending ?? false) {
                        postsByID[postID] = DanbooruPostCardState(post: fetchedPost)
                    }
                }

                let persistedInteractions = await interactionStore.interactionMap(
                    host: configuration.baseURL.absoluteString,
                    login: configuration.login,
                    postIDs: favoritePostIDs
                )

                var orderedCards: [DanbooruPostCardState] = []
                for postID in favoritePostIDs {
                    guard var card = postsByID[postID] else { continue }
                    if let snapshot = persistedInteractions[postID] {
                        card.applyPersistedInteraction(snapshot)
                    }
                    orderedCards.append(card)
                }
                return orderedCards
            }
            favoritePosts = mappedFavorites
            DanbooruDiagnostics.ui.info("Profile reload success favorites=\(mappedFavorites.count, privacy: .public)")
        } catch {
            if isAsyncCancellationError(error) {
                DanbooruDiagnostics.ui.info("Profile reload cancelled")
                errorMessage = nil
                return
            }
            DanbooruDiagnostics.ui.error("Profile reload failed error=\(error.localizedDescription, privacy: .public)")
            errorMessage = error.localizedDescription
        }
    }
}
