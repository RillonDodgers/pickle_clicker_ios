import SwiftUI
import UIKit

final class DanbooruHostingController: UIHostingController<DanbooruRootView> {
    init(openAppHandler: @escaping (HiddenAppDestination) -> Void, closeHandler: @escaping () -> Void) {
        super.init(rootView: DanbooruRootView(openAppHandler: openAppHandler, closeHandler: closeHandler))
        title = "Danbooru"
    }

    @MainActor @preconcurrency required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
