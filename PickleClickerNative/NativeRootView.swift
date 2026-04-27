import Combine
import SwiftUI

@MainActor
final class NativeRootModel: ObservableObject {
    @Published var selectedDestination: HiddenAppDestination = .game

    func open(_ destination: HiddenAppDestination) {
        selectedDestination = destination
    }

    func closeCurrent() {
        selectedDestination = .game
    }
}

struct NativeRootView: View {
    @StateObject private var model = NativeRootModel()

    var body: some View {
        Group {
            switch model.selectedDestination {
            case .game:
                NavigationStack {
                    PickleGameRootView(openAppHandler: model.open)
                }
            case .channing:
                FourChanRootView(openAppHandler: model.open, closeHandler: model.closeCurrent)
            case .gallery:
                ImmichRootView(openAppHandler: model.open, closeHandler: model.closeCurrent)
            case .danbooru:
                DanbooruRootView(openAppHandler: model.open, closeHandler: model.closeCurrent)
            }
        }
        .environment(\.hiddenAppActions, HiddenAppActions(
            openApp: model.open,
            close: model.closeCurrent
        ))
    }
}
