import SwiftUI

struct FourChanSettingsView: View {
    @EnvironmentObject private var appModel: FourChanAppModel

    var body: some View {
        NativeAppScreenContainer(title: "Settings", currentApp: .channing) {
            Form {
                Section("Browsing") {
                    Toggle("Only show work-safe boards", isOn: binding(for: \.onlyShowWorksafeBoards))
                }

                Section {
                    Button("Save Preferences") {
                        appModel.saveSettings()
                    }
                    .buttonStyle(.borderedProminent)
                }

                if let statusMessage = appModel.settingsStatusMessage {
                    Section("Status") {
                        Text(statusMessage)
                    }
                }
            }
        }
    }

    private func binding(for keyPath: WritableKeyPath<FourChanSettings, Bool>) -> Binding<Bool> {
        Binding(
            get: { appModel.settingsStore.settings[keyPath: keyPath] },
            set: { appModel.settingsStore.settings[keyPath: keyPath] = $0 }
        )
    }
}
