import SwiftUI

struct ImmichSettingsView: View {
    @EnvironmentObject private var appModel: ImmichAppModel

    var body: some View {
        NativeAppScreenContainer(title: "Settings", currentApp: .gallery) {
            Form {
                Section("Connection") {
                    TextField("https://immich.example.com", text: binding(for: \.baseURLString))
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                    SecureField("API Key", text: binding(for: \.apiKey))
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
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

                if let user = appModel.currentUser {
                    Section("User") {
                        Text(user.name)
                        Text(user.email)
                            .foregroundStyle(.secondary)
                    }
                }

                if let statusMessage = appModel.settingsStatusMessage {
                    Section("Status") {
                        Text(statusMessage)
                            .foregroundStyle(statusMessage.hasPrefix("Connected") ? .green : .secondary)
                    }
                }
            }
        }
    }

    private func binding(for keyPath: WritableKeyPath<ImmichSettings, String>) -> Binding<String> {
        Binding(
            get: { appModel.settingsStore.settings[keyPath: keyPath] },
            set: { appModel.settingsStore.settings[keyPath: keyPath] = $0 }
        )
    }
}
