import Combine
import SwiftUI

@MainActor
final class ImmichAlbumsViewModel: ObservableObject {
    @Published private(set) var albums: [ImmichAlbumSummary] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private var lastConfigurationKey: String?

    func ensureLoaded(using configuration: ImmichClientConfiguration?) async {
        guard let configuration else { return }
        let configurationKey = "\(configuration.baseURL.absoluteString)|\(configuration.apiKey)"
        guard albums.isEmpty || lastConfigurationKey != configurationKey else { return }
        await reload(using: configuration)
    }

    func reload(using configuration: ImmichClientConfiguration?) async {
        guard let configuration else { return }
        isLoading = true
        errorMessage = nil

        let previousAlbums = albums
        let previousConfigurationKey = lastConfigurationKey
        lastConfigurationKey = "\(configuration.baseURL.absoluteString)|\(configuration.apiKey)"

        do {
            albums = try await ImmichAPIClient(configuration: configuration)
                .fetchAlbums()
                .sorted { lhs, rhs in
                    if lhs.assetCount == rhs.assetCount {
                        return lhs.albumName.localizedCaseInsensitiveCompare(rhs.albumName) == .orderedAscending
                    }
                    return lhs.assetCount > rhs.assetCount
                }
        } catch {
            if isAsyncCancellationError(error) {
                errorMessage = nil
                return
            }
            albums = previousAlbums
            lastConfigurationKey = previousConfigurationKey
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}
