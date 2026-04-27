import Combine
import SwiftUI

@MainActor
final class ImmichAppModel: ObservableObject {
    enum ValidationStatus: Equatable {
        case unknown
        case validating
        case valid
        case invalid(String)
    }

    enum Tab: Hashable {
        case library
        case albums
        case tags
        case settings
    }

    @Published var selectedTab: Tab = .library
    @Published var settingsStatusMessage: String?
    @Published private(set) var reloadToken = UUID()
    @Published private(set) var validationStatus: ValidationStatus = .unknown
    @Published private(set) var currentUser: ImmichUser?

    let settingsStore: ImmichSettingsStore

    private let openAppHandler: (HiddenAppDestination) -> Void
    private let closeHandler: () -> Void
    private var lastValidatedConfigurationKey: String?

    init(
        settingsStore: ImmichSettingsStore,
        openAppHandler: @escaping (HiddenAppDestination) -> Void,
        closeHandler: @escaping () -> Void
    ) {
        self.settingsStore = settingsStore
        self.openAppHandler = openAppHandler
        self.closeHandler = closeHandler
    }

    var configuration: ImmichClientConfiguration? {
        settingsStore.configuration
    }

    var canLoadProtectedContent: Bool {
        validationStatus == .valid
    }

    func makeClient() throws -> ImmichAPIClient {
        guard let configuration else {
            throw ImmichAPIError.invalidConfiguration
        }
        return ImmichAPIClient(configuration: configuration)
    }

    func triggerReload() {
        reloadToken = UUID()
    }

    func switchToSettings() {
        selectedTab = .settings
    }

    func validateConfigurationIfNeeded(force: Bool = false) async {
        guard let configuration else {
            validationStatus = .invalid("Add a valid Immich URL and API key.")
            settingsStatusMessage = "Add a valid Immich URL and API key."
            selectedTab = .settings
            currentUser = nil
            return
        }

        let configurationKey = "\(configuration.baseURL.absoluteString)|\(configuration.apiKey)"
        if !force, validationStatus == .valid, configurationKey == lastValidatedConfigurationKey {
            return
        }

        validationStatus = .validating

        do {
            let user = try await makeClient().fetchCurrentUser()
            currentUser = user
            validationStatus = .valid
            lastValidatedConfigurationKey = configurationKey
            settingsStatusMessage = "Connected as \(user.name)."
            if selectedTab == .settings {
                selectedTab = .library
            }
        } catch {
            validationStatus = .invalid(error.localizedDescription)
            settingsStatusMessage = error.localizedDescription
            lastValidatedConfigurationKey = nil
            currentUser = nil
            selectedTab = .settings
        }
    }

    func saveSettings() async {
        settingsStore.save()
        triggerReload()
        await validateConfigurationIfNeeded(force: true)
    }

    func testConnection() async {
        await validateConfigurationIfNeeded(force: true)
    }

    func openApp(_ destination: HiddenAppDestination) {
        openAppHandler(destination)
    }

    func close() {
        closeHandler()
    }
}
