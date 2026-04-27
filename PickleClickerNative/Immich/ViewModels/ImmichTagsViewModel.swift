import Combine
import SwiftUI

@MainActor
final class ImmichTagsViewModel: ObservableObject {
    @Published private(set) var tags: [ImmichTagCount] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private var lastConfigurationKey: String?

    func ensureLoaded(using configuration: ImmichClientConfiguration?) async {
        guard let configuration else { return }
        let configurationKey = "\(configuration.baseURL.absoluteString)|\(configuration.apiKey)"
        guard tags.isEmpty || lastConfigurationKey != configurationKey else { return }
        await reload(using: configuration)
    }

    func reload(using configuration: ImmichClientConfiguration?) async {
        guard let configuration else { return }
        isLoading = true
        errorMessage = nil

        let previousTags = tags
        let previousConfigurationKey = lastConfigurationKey
        lastConfigurationKey = "\(configuration.baseURL.absoluteString)|\(configuration.apiKey)"

        do {
            let client = ImmichAPIClient(configuration: configuration)
            let fetchedTags = try await client.fetchTags()
            var countedTags: [ImmichTagCount] = []
            countedTags.reserveCapacity(fetchedTags.count)

            for tag in fetchedTags {
                let result = try await client.searchAssets(page: 1, pageSize: 1, tagIDs: [tag.id])
                countedTags.append(ImmichTagCount(tag: tag, assetCount: result.total))
            }

            tags = countedTags.sorted { lhs, rhs in
                if lhs.assetCount == rhs.assetCount {
                    return lhs.tag.displayName.localizedCaseInsensitiveCompare(rhs.tag.displayName) == .orderedAscending
                }
                return lhs.assetCount > rhs.assetCount
            }
        } catch {
            if isAsyncCancellationError(error) {
                errorMessage = nil
                return
            }
            tags = previousTags
            lastConfigurationKey = previousConfigurationKey
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}
