import SwiftUI

struct DanbooruSaveToImmichButton<LabelContent: View>: View {
    let post: DanbooruPostCardState
    let configuration: DanbooruClientConfiguration?
    @ViewBuilder let label: () -> LabelContent

    @State private var isSaving = false
    @State private var alertMessage: String?

    var body: some View {
        Button {
            Task {
                await save()
            }
        } label: {
            label()
        }
        .disabled(isSaving || configuration == nil || (post.fullImageURL ?? post.imageURL) == nil)
        .alert("Immich Upload", isPresented: Binding(
            get: { alertMessage != nil },
            set: { if !$0 { alertMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(alertMessage ?? "")
        }
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }

        do {
            guard let configuration else {
                throw DanbooruAPIError.invalidConfiguration
            }

            guard let sourceURL = post.fullImageURL ?? post.imageURL else {
                throw ImmichAPIError.requestFailed("That post does not have downloadable media.")
            }

            let settingsStore = ImmichSettingsStore()
            guard let immichConfiguration = settingsStore.configuration else {
                throw ImmichAPIError.invalidConfiguration
            }

            let danbooruClient = DanbooruAPIClient(configuration: configuration)
            let authenticatedRequest = try danbooruClient.makeAuthenticatedRequest(url: sourceURL, accept: "*/*")
            let mediaRequest = SharedRemoteMediaRequest(
                namespace: "danbooru",
                url: authenticatedRequest.url ?? sourceURL,
                headers: authenticatedRequest.allHTTPHeaderFields ?? [:],
                cacheIdentity: "danbooru|\(post.id)|\(sourceURL.absoluteString)"
            )

            let suggestedFilename = sourceURL.lastPathComponent.isEmpty ? "danbooru-\(post.id).bin" : sourceURL.lastPathComponent
            let immichClient = ImmichAPIClient(configuration: immichConfiguration)
            _ = try await immichClient.uploadRemoteMedia(
                mediaRequest,
                suggestedFilename: suggestedFilename,
                albumName: "Booru",
                additionalAlbumNames: post.characterAlbumNames,
                tagNames: post.tagNames,
                sourceDescription: "Danbooru"
            )
            alertMessage = "Saved 1 attachment to Immich."
        } catch {
            alertMessage = error.localizedDescription
        }
    }
}
