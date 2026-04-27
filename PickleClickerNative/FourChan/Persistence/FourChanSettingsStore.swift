import Combine
import Foundation

struct FourChanSettings: Equatable {
    var onlyShowWorksafeBoards = true
}

@MainActor
final class FourChanSettingsStore: ObservableObject {
    @Published var settings: FourChanSettings

    private let defaults: UserDefaults
    private let settingsKey = "FourChanSettings.onlyShowWorksafeBoards"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        settings = FourChanSettings(
            onlyShowWorksafeBoards: defaults.object(forKey: settingsKey) as? Bool ?? true
        )
    }

    func save() {
        defaults.set(settings.onlyShowWorksafeBoards, forKey: settingsKey)
    }
}
