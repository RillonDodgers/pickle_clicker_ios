import Combine
import Foundation
import OSLog
import SwiftUI

@MainActor
final class DanbooruAppModel: ObservableObject {
    enum ValidationStatus: Equatable {
        case unknown
        case validating
        case valid
        case invalid(String)
    }

    enum Tab: Hashable {
        case posts
        case inbox
        case profile
        case forum
        case settings
    }

    @Published var selectedTab: Tab = .posts
    @Published var settingsStatusMessage: String?
    @Published private(set) var reloadToken = UUID()
    @Published private(set) var validationStatus: ValidationStatus = .unknown

    let settingsStore: DanbooruSettingsStore

    private let openAppHandler: (HiddenAppDestination) -> Void
    private let closeHandler: () -> Void
    private var lastValidatedConfigurationKey: String?

    init(
        settingsStore: DanbooruSettingsStore,
        openAppHandler: @escaping (HiddenAppDestination) -> Void,
        closeHandler: @escaping () -> Void
    ) {
        self.settingsStore = settingsStore
        self.openAppHandler = openAppHandler
        self.closeHandler = closeHandler
    }

    var configuration: DanbooruClientConfiguration? {
        settingsStore.configuration
    }

    var canLoadProtectedContent: Bool {
        validationStatus == .valid
    }

    func makeClient() throws -> DanbooruAPIClient {
        guard let configuration else {
            throw DanbooruAPIError.invalidConfiguration
        }

        return DanbooruAPIClient(configuration: configuration)
    }

    func switchToSettings() {
        selectedTab = .settings
    }

    func triggerReload() {
        reloadToken = UUID()
    }

    func validateConfigurationIfNeeded(force: Bool = false) async {
        DanbooruDiagnostics.app.info("validateConfigurationIfNeeded force=\(force, privacy: .public)")
        guard let configuration else {
            DanbooruDiagnostics.app.error("validateConfigurationIfNeeded missing configuration")
            validationStatus = .invalid("Add a valid URL, login, API key, and atf-anti-bot cookie.")
            settingsStatusMessage = "Add a valid URL, login, API key, and atf-anti-bot cookie."
            selectedTab = .settings
            return
        }

        let configurationKey = "\(configuration.baseURL.absoluteString)|\(configuration.login)|\(configuration.apiKey)|\(configuration.atfAntiBotCookie)"
        if !force, validationStatus == .valid, lastValidatedConfigurationKey == configurationKey {
            DanbooruDiagnostics.app.info("validateConfigurationIfNeeded skipped already valid")
            return
        }

        validationStatus = .validating

        do {
            _ = try await makeClient().fetchCurrentUser()
            validationStatus = .valid
            lastValidatedConfigurationKey = configurationKey
            if selectedTab == .settings {
                selectedTab = .posts
            }
            settingsStatusMessage = "Connection verified. Danbooru is ready."
            DanbooruDiagnostics.app.info("validateConfigurationIfNeeded success")
        } catch {
            DanbooruDiagnostics.app.error("validateConfigurationIfNeeded failed error=\(error.localizedDescription, privacy: .public)")
            validationStatus = .invalid(error.localizedDescription)
            settingsStatusMessage = error.localizedDescription
            lastValidatedConfigurationKey = nil
            selectedTab = .settings
        }
    }

    func saveSettings() async {
        DanbooruDiagnostics.app.info("saveSettings start")
        do {
            try settingsStore.save()
            triggerReload()
            await validateConfigurationIfNeeded(force: true)
            DanbooruDiagnostics.app.info("saveSettings success")
        } catch {
            DanbooruDiagnostics.app.error("saveSettings failed error=\(error.localizedDescription, privacy: .public)")
            settingsStatusMessage = error.localizedDescription
            validationStatus = .invalid(error.localizedDescription)
            selectedTab = .settings
        }
    }

    func testConnection() async {
        await validateConfigurationIfNeeded(force: true)
    }

    func openApp(_ destination: HiddenAppDestination) {
        openAppHandler(destination)
    }

    func closeDanbooru() {
        closeHandler()
    }

}
