import Combine
import SwiftUI

@MainActor
final class ImmichLibraryViewModel: ObservableObject {
    @Published private(set) var assets: [ImmichAsset] = []
    @Published private(set) var isLoading = false
    @Published private(set) var isLoadingNextPage = false
    @Published var errorMessage: String?

    private var nextPage = 1
    private var hasMorePages = true
    private var lastConfigurationKey: String?

    func ensureLoaded(using configuration: ImmichClientConfiguration?) async {
        guard let configuration else { return }
        let configurationKey = "\(configuration.baseURL.absoluteString)|\(configuration.apiKey)"
        guard assets.isEmpty || lastConfigurationKey != configurationKey else { return }
        await reload(using: configuration)
    }

    func reload(using configuration: ImmichClientConfiguration?) async {
        guard let configuration else { return }
        isLoading = true
        errorMessage = nil
        let previousAssets = assets
        let previousNextPage = nextPage
        let previousHasMorePages = hasMorePages
        let previousConfigurationKey = lastConfigurationKey
        nextPage = 1
        hasMorePages = true
        lastConfigurationKey = "\(configuration.baseURL.absoluteString)|\(configuration.apiKey)"

        do {
            let page = try await ImmichAPIClient(configuration: configuration).searchAssets(page: nextPage)
            assets = page.items
            nextPage = 2
            hasMorePages = page.nextPage != nil || !page.items.isEmpty
        } catch {
            if isAsyncCancellationError(error) {
                errorMessage = nil
                return
            }
            assets = previousAssets
            nextPage = previousNextPage
            hasMorePages = previousHasMorePages
            lastConfigurationKey = previousConfigurationKey
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func loadMoreIfNeeded(currentItem: ImmichAsset, configuration: ImmichClientConfiguration?) async {
        guard let configuration, hasMorePages, !isLoading, !isLoadingNextPage else { return }
        guard let index = assets.firstIndex(of: currentItem), index >= assets.count - 12 else { return }

        isLoadingNextPage = true
        defer { isLoadingNextPage = false }

        do {
            let page = try await ImmichAPIClient(configuration: configuration).searchAssets(page: nextPage)
            let existingIDs = Set(assets.map(\.id))
            assets.append(contentsOf: page.items.filter { !existingIDs.contains($0.id) })
            nextPage += 1
            hasMorePages = page.nextPage != nil || !page.items.isEmpty
        } catch {
            if isAsyncCancellationError(error) {
                errorMessage = nil
                return
            }
            errorMessage = error.localizedDescription
        }
    }
}
