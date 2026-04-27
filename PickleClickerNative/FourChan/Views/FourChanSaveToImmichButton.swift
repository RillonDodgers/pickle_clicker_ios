import SwiftUI

struct FourChanSaveToImmichButton<LabelContent: View>: View {
    let boardID: String
    let posts: [FourChanPost]
    let mode: Mode
    @ViewBuilder let label: () -> LabelContent

    @State private var isSaving = false
    @State private var alertMessage: String?

    enum Mode {
        case post(FourChanPost)
        case thread
    }

    var body: some View {
        Button {
            Task {
                await save()
            }
        } label: {
            label()
        }
        .disabled(isSaving)
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
            let settingsStore = ImmichSettingsStore()
            guard let configuration = settingsStore.configuration else {
                throw ImmichAPIError.invalidConfiguration
            }

            let client = ImmichAPIClient(configuration: configuration)
            switch mode {
            case let .post(post):
                guard let request = post.mediaRequest(boardID: boardID) else {
                    throw ImmichAPIError.requestFailed("That post does not have downloadable media.")
                }
                _ = try await client.uploadRemoteMedia(
                    request,
                    suggestedFilename: post.suggestedFilename,
                    albumName: "Channing",
                    sourceDescription: "4chan"
                )
                alertMessage = "Saved 1 attachment to Immich."
            case .thread:
                let requests = posts.compactMap { post -> (SharedRemoteMediaRequest, String)? in
                    guard let request = post.mediaRequest(boardID: boardID) else { return nil }
                    return (request, post.suggestedFilename)
                }
                guard !requests.isEmpty else {
                    throw ImmichAPIError.requestFailed("This thread does not have any downloadable attachments.")
                }
                for (request, filename) in requests {
                    _ = try await client.uploadRemoteMedia(
                        request,
                        suggestedFilename: filename,
                        albumName: "Channing",
                        sourceDescription: "4chan"
                    )
                }
                alertMessage = "Saved \(requests.count) attachment\(requests.count == 1 ? "" : "s") to Immich."
            }
        } catch {
            alertMessage = error.localizedDescription
        }
    }
}
