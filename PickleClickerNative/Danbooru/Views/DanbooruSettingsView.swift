import SwiftUI

struct DanbooruSettingsView: View {
    @EnvironmentObject private var appModel: DanbooruAppModel
    @State private var isSyncingFavoritesToImmich = false
    @State private var favoritesSyncStatus: String?

    var body: some View {
        DanbooruScreenContainer(title: "Settings") {
            Form {
                Section("Connection") {
                    TextField("https://danbooru.example.com", text: binding(for: \.baseURLString))
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                    TextField("Login", text: binding(for: \.login))
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    SecureField("API Key", text: binding(for: \.apiKey))
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField("atf-anti-bot cookie", text: binding(for: \.atfAntiBotCookie))
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }

                Section("Comment Sorting") {
                    Picker("Post Comments", selection: binding(for: \.postCommentSortOrderRawValue)) {
                        ForEach(DanbooruCommentSortOrder.allCases, id: \.rawValue) { order in
                            Text(order.title).tag(order.rawValue)
                        }
                    }

                    Picker("Forum Replies", selection: binding(for: \.forumPostSortOrderRawValue)) {
                        ForEach(DanbooruCommentSortOrder.allCases, id: \.rawValue) { order in
                            Text(order.title).tag(order.rawValue)
                        }
                    }
                }

                Section {
                    Button("Save & Validate") {
                        Task {
                            await appModel.saveSettings()
                        }
                    }
                    .buttonStyle(.borderedProminent)

                    Button("Test Connection") {
                        Task {
                            await appModel.testConnection()
                        }
                    }
                }

                Section("Immich") {
                    Button {
                        Task {
                            await syncFavoritesToImmich()
                        }
                    } label: {
                        HStack {
                            Text("Download All Favorites to Immich")
                            Spacer()
                            if isSyncingFavoritesToImmich {
                                ProgressView()
                            }
                        }
                    }
                    .disabled(isSyncingFavoritesToImmich || appModel.configuration == nil)

                    if let favoritesSyncStatus {
                        Text(favoritesSyncStatus)
                            .foregroundStyle(.secondary)
                    }
                }

                if let statusMessage = appModel.settingsStatusMessage {
                    Section("Status") {
                        Text(statusMessage)
                            .foregroundStyle(statusMessage.contains("verified") ? .green : .secondary)
                    }
                }
            }
        }
    }

    private func binding(for keyPath: WritableKeyPath<DanbooruSettings, String>) -> Binding<String> {
        Binding(
            get: { appModel.settingsStore.settings[keyPath: keyPath] },
            set: { appModel.settingsStore.settings[keyPath: keyPath] = $0 }
        )
    }

    private func syncFavoritesToImmich() async {
        guard let configuration = appModel.configuration else {
            favoritesSyncStatus = DanbooruAPIError.invalidConfiguration.localizedDescription
            return
        }

        isSyncingFavoritesToImmich = true
        favoritesSyncStatus = "Preparing favorites sync…"
        defer { isSyncingFavoritesToImmich = false }

        do {
            let summary = try await DanbooruImmichSync.syncAllFavorites(configuration: configuration) { status in
                favoritesSyncStatus = status
            }
            favoritesSyncStatus = "Synced \(summary.uploadedCount) of \(summary.totalFavorites) favorites to Immich. Skipped \(summary.skippedCount), failed \(summary.failedCount)."
        } catch {
            favoritesSyncStatus = error.localizedDescription
        }
    }
}
