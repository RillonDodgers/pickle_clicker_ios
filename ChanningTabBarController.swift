import SwiftUI
import UIKit

enum HiddenAppDestination: String, CaseIterable {
    case game
    case channing
    case gallery
    case danbooru

    var title: String {
        switch self {
        case .game:
            return "Cultivator"
        case .channing:
            return "Channing"
        case .gallery:
            return "Gallery"
        case .danbooru:
            return "Danbooru"
        }
    }
}

final class ChanningTabBarController: UIHostingController<FourChanRootView> {
    init(openAppHandler: @escaping (HiddenAppDestination) -> Void, closeHandler: @escaping () -> Void) {
        super.init(
            rootView: FourChanRootView(
                openAppHandler: openAppHandler,
                closeHandler: closeHandler
            )
        )
        title = HiddenAppDestination.channing.title
    }

    @MainActor @preconcurrency required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

final class GalleryTabBarController: UIHostingController<ImmichRootView> {
    init(openAppHandler: @escaping (HiddenAppDestination) -> Void, closeHandler: @escaping () -> Void) {
        super.init(
            rootView: ImmichRootView(
                openAppHandler: openAppHandler,
                closeHandler: closeHandler
            )
        )
        title = HiddenAppDestination.gallery.title
    }

    @MainActor @preconcurrency required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
