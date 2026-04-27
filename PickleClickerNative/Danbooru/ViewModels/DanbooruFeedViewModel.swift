import Combine
import Foundation
import OSLog

@MainActor
final class DanbooruFeedViewModel: ObservableObject {
    @Published private(set) var posts: [DanbooruPostCardState] = []
    @Published private(set) var isLoading = false
    @Published private(set) var isLoadingNextPage = false
    @Published var errorMessage: String?
    @Published var searchText = ""
    @Published private(set) var appliedQuery = ""

    private var currentPage = 1
    private var canLoadMore = true
    private var lastConfigurationKey: String?
    private var lastLoadedQuery = ""
    private var loadVersion = UUID()
    private let interactionStore = DanbooruPostInteractionStore.shared

    init(initialQuery: String = "") {
        let normalizedQuery = initialQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        searchText = normalizedQuery
        appliedQuery = normalizedQuery
        lastLoadedQuery = normalizedQuery
    }

    var emptyStateMessage: String {
        appliedQuery.isEmpty ? "No posts yet." : "No posts matched that tag search."
    }

    func ensureLoaded(using configuration: DanbooruClientConfiguration?) async {
        DanbooruDiagnostics.state.info(
            "Feed ensureLoaded start posts=\(self.posts.count, privacy: .public) query=\(self.appliedQuery, privacy: .public) configPresent=\(configuration != nil, privacy: .public)"
        )
        guard let configuration else { return }
        let configurationKey = makeConfigurationKey(configuration)

        if !posts.isEmpty,
           lastConfigurationKey == configurationKey,
           lastLoadedQuery == appliedQuery {
            DanbooruDiagnostics.ui.info("Feed keep existing in-memory state count=\(self.posts.count, privacy: .public)")
            return
        }

        await resetAndReload(using: configuration)
    }

    func resetAndReload(using configuration: DanbooruClientConfiguration?) async {
        guard let configuration else { return }

        DanbooruDiagnostics.state.info(
            "Feed resetAndReload start existingPosts=\(self.posts.count, privacy: .public) query=\(self.appliedQuery, privacy: .public)"
        )
        resetFeedState(for: configuration)
        isLoading = true
        errorMessage = nil
        let version = UUID()
        loadVersion = version

        do {
            let firstPage = try await fetchPage(
                page: 1,
                configuration: configuration,
                query: appliedQuery
            )

            guard version == loadVersion else { return }

            posts = firstPage
            currentPage = 1
            canLoadMore = !firstPage.isEmpty
            lastConfigurationKey = makeConfigurationKey(configuration)
            lastLoadedQuery = appliedQuery
            DanbooruDiagnostics.ui.info("Feed reload success page=1 count=\(self.posts.count, privacy: .public)")
            DanbooruDiagnostics.state.info(
                "Feed resetAndReload committed posts=\(self.posts.count, privacy: .public) canLoadMore=\(self.canLoadMore, privacy: .public)"
            )
        } catch {
            guard version == loadVersion else { return }
            if isAsyncCancellationError(error) {
                DanbooruDiagnostics.state.info("Feed resetAndReload cancelled")
                errorMessage = nil
            } else {
                DanbooruDiagnostics.ui.error("Feed reload failed error=\(error.localizedDescription, privacy: .public)")
                errorMessage = error.localizedDescription
            }
        }

        if version == loadVersion {
            isLoading = false
        }
    }

    func reload(using configuration: DanbooruClientConfiguration?) async {
        guard let configuration else { return }

        DanbooruDiagnostics.state.info(
            "Feed reload start existingPosts=\(self.posts.count, privacy: .public) query=\(self.appliedQuery, privacy: .public)"
        )
        isLoading = true
        errorMessage = nil
        let version = UUID()
        loadVersion = version

        do {
            let firstPage = try await fetchPage(
                page: 1,
                configuration: configuration,
                query: appliedQuery
            )

            guard version == loadVersion else { return }

            posts = firstPage
            currentPage = 1
            canLoadMore = !firstPage.isEmpty
            lastConfigurationKey = makeConfigurationKey(configuration)
            lastLoadedQuery = appliedQuery
            DanbooruDiagnostics.ui.info("Feed reload success page=1 count=\(self.posts.count, privacy: .public)")
            DanbooruDiagnostics.state.info(
                "Feed reload committed posts=\(self.posts.count, privacy: .public) canLoadMore=\(self.canLoadMore, privacy: .public)"
            )
        } catch {
            guard version == loadVersion else { return }
            if isAsyncCancellationError(error) {
                DanbooruDiagnostics.state.info("Feed reload cancelled")
                errorMessage = nil
            } else {
                DanbooruDiagnostics.ui.error("Feed reload failed error=\(error.localizedDescription, privacy: .public)")
                errorMessage = error.localizedDescription
            }
        }

        if version == loadVersion {
            isLoading = false
        }
    }

    func submitSearch(using configuration: DanbooruClientConfiguration?) async {
        appliedQuery = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        await resetAndReload(using: configuration)
    }

    func clearSearch(using configuration: DanbooruClientConfiguration?) async {
        searchText = ""
        appliedQuery = ""
        await resetAndReload(using: configuration)
    }

    func loadMoreIfNeeded(currentItem: DanbooruPostCardState, configuration: DanbooruClientConfiguration?) async {
        guard let configuration,
              canLoadMore,
              !isLoading,
              !isLoadingNextPage,
              posts.last?.id == currentItem.id else { return }

        isLoadingNextPage = true
        defer { isLoadingNextPage = false }

        let targetPage = currentPage + 1

        do {
            let nextPagePosts = try await fetchPage(
                page: targetPage,
                configuration: configuration,
                query: appliedQuery
            )

            let existingIDs = Set(posts.map(\.id))
            posts.append(contentsOf: nextPagePosts.filter { !existingIDs.contains($0.id) })
            currentPage = targetPage
            canLoadMore = !nextPagePosts.isEmpty
            DanbooruDiagnostics.state.info(
                "Feed loadMore committed page=\(targetPage, privacy: .public) added=\(nextPagePosts.count, privacy: .public) total=\(self.posts.count, privacy: .public)"
            )
        } catch {
            if isAsyncCancellationError(error) {
                DanbooruDiagnostics.state.info("Feed loadMore cancelled page=\(targetPage, privacy: .public)")
                errorMessage = nil
                return
            }
            errorMessage = error.localizedDescription
        }
    }

    func refresh(using configuration: DanbooruClientConfiguration?) async {
        DanbooruDiagnostics.state.info("Feed refresh invoked")
        await reload(using: configuration)
    }

    func upvote(_ post: DanbooruPostCardState, configuration: DanbooruClientConfiguration?) async {
        await updateVote(for: post.id, to: .up, configuration: configuration)
    }

    func downvote(_ post: DanbooruPostCardState, configuration: DanbooruClientConfiguration?) async {
        await updateVote(for: post.id, to: .down, configuration: configuration)
    }

    func toggleFavorite(_ post: DanbooruPostCardState, configuration: DanbooruClientConfiguration?) async {
        guard let configuration else {
            errorMessage = DanbooruAPIError.invalidConfiguration.localizedDescription
            return
        }

        let oldPosts = posts
        guard let index = posts.firstIndex(where: { $0.id == post.id }) else { return }
        let wasFavorited = posts[index].isFavorited

        posts[index].applyFavorite(!wasFavorited)
        if !wasFavorited {
            posts[index].applyVote(.up)
        }

        do {
            let client = DanbooruAPIClient(configuration: configuration)
            if wasFavorited {
                try await client.unfavorite(postID: post.id)
            } else {
                try await client.favorite(postID: post.id)
                do {
                    try await client.vote(postID: post.id, score: .up)
                } catch {
                    if !isBenignMutationError(error) {
                        throw error
                    }
                }
                do {
                    try await DanbooruImmichSync.uploadPost(posts[index], configuration: configuration, client: client)
                } catch {
                    await interactionStore.save(card: posts[index], host: configuration.baseURL.absoluteString, login: configuration.login)
                    errorMessage = "Favorited on Danbooru, but Immich upload failed: \(error.localizedDescription)"
                    return
                }
            }
            await interactionStore.save(card: posts[index], host: configuration.baseURL.absoluteString, login: configuration.login)
        } catch {
            posts = oldPosts
            errorMessage = error.localizedDescription
        }
    }

    private func updateVote(for postID: Int, to vote: DanbooruVoteDirection, configuration: DanbooruClientConfiguration?) async {
        guard let configuration else {
            errorMessage = DanbooruAPIError.invalidConfiguration.localizedDescription
            return
        }

        let oldPosts = posts
        guard let index = posts.firstIndex(where: { $0.id == postID }) else { return }
        posts[index].applyVote(vote)

        do {
            try await DanbooruAPIClient(configuration: configuration).vote(postID: postID, score: vote)
            await interactionStore.save(card: posts[index], host: configuration.baseURL.absoluteString, login: configuration.login)
        } catch {
            if isBenignMutationError(error) {
                await interactionStore.save(card: posts[index], host: configuration.baseURL.absoluteString, login: configuration.login)
                return
            }
            posts = oldPosts
            errorMessage = error.localizedDescription
        }
    }

    private func fetchPage(
        page: Int,
        configuration: DanbooruClientConfiguration,
        query: String
    ) async throws -> [DanbooruPostCardState] {
        DanbooruDiagnostics.state.info(
            "Feed fetchPage start page=\(page, privacy: .public) query=\(query, privacy: .public)"
        )
        let fetchedPosts = try await DanbooruAPIClient(configuration: configuration).fetchPosts(
            page: page,
            tags: query.isEmpty ? nil : query
        )
        let visiblePosts = fetchedPosts.filter { !($0.isPending ?? false) }
        var mappedPosts = visiblePosts.map(DanbooruPostCardState.init)
        let persistedInteractions = await interactionStore.interactionMap(
            host: configuration.baseURL.absoluteString,
            login: configuration.login,
            postIDs: mappedPosts.map(\.id)
        )
        mappedPosts = mappedPosts.map { post in
            var post = post
            if let snapshot = persistedInteractions[post.id] {
                post.applyPersistedInteraction(snapshot)
            }
            return post
        }
        DanbooruDiagnostics.state.info(
            "Feed fetchPage finish page=\(page, privacy: .public) fetched=\(fetchedPosts.count, privacy: .public) visible=\(visiblePosts.count, privacy: .public) mapped=\(mappedPosts.count, privacy: .public)"
        )
        return mappedPosts
    }

    private func makeConfigurationKey(_ configuration: DanbooruClientConfiguration) -> String {
        "\(configuration.baseURL.absoluteString)|\(configuration.login)"
    }

    private func resetFeedState(for configuration: DanbooruClientConfiguration) {
        DanbooruDiagnostics.state.info(
            "Feed reset state oldPosts=\(self.posts.count, privacy: .public) query=\(self.appliedQuery, privacy: .public)"
        )
        posts = []
        currentPage = 1
        canLoadMore = true
        lastConfigurationKey = makeConfigurationKey(configuration)
        lastLoadedQuery = appliedQuery
    }

    private func isBenignMutationError(_ error: Error) -> Bool {
        guard let apiError = error as? DanbooruAPIError else {
            return false
        }

        switch apiError {
        case let .requestFailed(reason):
            let lowered = reason.lowercased()
            return lowered.contains("duplicate")
                || lowered.contains("already exists")
                || lowered.contains("already favorited")
                || lowered.contains("already upvoted")
        default:
            return false
        }
    }
}
