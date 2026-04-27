import Combine
import Foundation

@MainActor
final class ImmichSettingsStore: ObservableObject {
    @Published var settings: ImmichSettings

    private let defaults: UserDefaults
    private enum Key {
        static let baseURL = "ImmichSettings.baseURL"
        static let apiKey = "ImmichSettings.apiKey"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        settings = ImmichSettings(
            baseURLString: defaults.string(forKey: Key.baseURL) ?? "",
            apiKey: defaults.string(forKey: Key.apiKey) ?? ""
        )
    }

    var configuration: ImmichClientConfiguration? {
        settings.configuration
    }

    func save() {
        defaults.set(settings.baseURLString.trimmingCharacters(in: .whitespacesAndNewlines), forKey: Key.baseURL)
        defaults.set(settings.apiKey.trimmingCharacters(in: .whitespacesAndNewlines), forKey: Key.apiKey)
    }
}
