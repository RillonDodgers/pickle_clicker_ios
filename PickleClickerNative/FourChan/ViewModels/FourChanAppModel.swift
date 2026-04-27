import Combine
import SwiftUI

@MainActor
final class FourChanAppModel: ObservableObject {
    enum Tab: Hashable {
        case boards
        case settings
    }

    @Published var selectedTab: Tab = .boards
    @Published var settingsStatusMessage: String?

    let settingsStore: FourChanSettingsStore

    private let openAppHandler: (HiddenAppDestination) -> Void
    private let closeHandler: () -> Void

    init(
        settingsStore: FourChanSettingsStore,
        openAppHandler: @escaping (HiddenAppDestination) -> Void,
        closeHandler: @escaping () -> Void
    ) {
        self.settingsStore = settingsStore
        self.openAppHandler = openAppHandler
        self.closeHandler = closeHandler
    }

    func saveSettings() {
        settingsStore.save()
        settingsStatusMessage = settingsStore.settings.onlyShowWorksafeBoards
            ? "Filtering to work-safe boards."
            : "Showing all boards, including NSFW boards."
    }

    func openApp(_ destination: HiddenAppDestination) {
        openAppHandler(destination)
    }

    func close() {
        closeHandler()
    }
}
