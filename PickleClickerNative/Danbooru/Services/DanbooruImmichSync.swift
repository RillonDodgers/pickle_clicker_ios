import Foundation

enum DanbooruImmichSync {
    struct SyncSummary {
        let totalFavorites: Int
        let uploadedCount: Int
        let skippedCount: Int
        let failedCount: Int
    }

    static func uploadPost(_ post: DanbooruPostCardState, configuration: DanbooruClientConfiguration) async throws {
        let client = DanbooruAPIClient(configuration: configuration)
        try await uploadPost(post, configuration: configuration, client: client)
    }

    static func uploadPost(
        _ post: DanbooruPostCardState,
        configuration: DanbooruClientConfiguration,
        client: DanbooruAPIClient
    ) async throws {
        guard let sourceURL = post.fullImageURL ?? post.imageURL else {
            throw ImmichAPIError.requestFailed("That post does not have downloadable media.")
        }

        let settingsStore = ImmichSettingsStore()
        guard let immichConfiguration = settingsStore.configuration else {
            throw ImmichAPIError.invalidConfiguration
        }

        let authenticatedRequest = try client.makeAuthenticatedRequest(url: sourceURL, accept: "*/*")
        let mediaRequest = SharedRemoteMediaRequest(
            namespace: "danbooru",
            url: authenticatedRequest.url ?? sourceURL,
            headers: authenticatedRequest.allHTTPHeaderFields ?? [:],
            cacheIdentity: "danbooru|\(post.id)|\(sourceURL.absoluteString)"
        )

        let suggestedFilename = sourceURL.lastPathComponent.isEmpty ? "danbooru-\(post.id).bin" : sourceURL.lastPathComponent
        _ = try await ImmichAPIClient(configuration: immichConfiguration).uploadRemoteMedia(
            mediaRequest,
            suggestedFilename: suggestedFilename,
            albumName: "Booru",
            additionalAlbumNames: post.characterAlbumNames,
            tagNames: post.tagNames,
            sourceDescription: "Danbooru"
        )
    }

    static func syncAllFavorites(
        configuration: DanbooruClientConfiguration,
        progress: (@MainActor @Sendable (String) -> Void)? = nil
    ) async throws -> SyncSummary {
        let client = DanbooruAPIClient(configuration: configuration)
        let user = try await client.fetchCurrentUser()
        let pageSize = 100

        var allFavoriteRecords: [DanbooruFavoriteRecord] = []
        var page = 1

        while true {
            await progress?("Loading favorites page \(page)…")
            let pageRecords = try await client.fetchFavorites(userID: user.id, page: page, limit: pageSize)
            guard !pageRecords.isEmpty else { break }
            allFavoriteRecords.append(contentsOf: pageRecords)
            if pageRecords.count < pageSize { break }
            page += 1
        }

        let favoritePostIDs = Array(NSOrderedSet(array: allFavoriteRecords.map(\.postID))) as? [Int] ?? allFavoriteRecords.map(\.postID)

        var uploadedCount = 0
        var skippedCount = 0
        var failedCount = 0

        for (index, postID) in favoritePostIDs.enumerated() {
            await progress?("Syncing favorite \(index + 1) of \(favoritePostIDs.count)…")

            do {
                let post = try await client.fetchPost(id: postID)
                if post.isPending ?? false {
                    skippedCount += 1
                    continue
                }

                try await uploadPost(DanbooruPostCardState(post: post), configuration: configuration, client: client)
                uploadedCount += 1
            } catch {
                failedCount += 1
            }
        }

        return SyncSummary(
            totalFavorites: favoritePostIDs.count,
            uploadedCount: uploadedCount,
            skippedCount: skippedCount,
            failedCount: failedCount
        )
    }
}
