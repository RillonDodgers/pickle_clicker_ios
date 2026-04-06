import HotwireNative
import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate, NavigatorDelegate, HiddenAppRouting {
    var window: UIWindow?

    private lazy var navigator = Navigator(
        configuration: .init(
            name: "main",
            startLocation: AppConfiguration.baseURL
        ),
        delegate: self
    )

    private weak var activeHiddenAppController: UIViewController?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }

        let window = UIWindow(windowScene: windowScene)
        navigator.rootViewController.setNavigationBarHidden(true, animated: false)
        window.rootViewController = navigator.rootViewController
        self.window = window
        window.makeKeyAndVisible()
        navigator.start()
    }

    func handle(proposal: VisitProposal, from navigator: Navigator) -> ProposalResult {
        if navigator !== self.navigator,
           activeHiddenAppController != nil,
           !isHiddenAppPath(proposal.url) {
            dismissHiddenAppAndRouteToMain(proposal.url)
            return .reject
        }

        switch proposal.viewController {
        case ChanningTabBarController.pathConfigurationIdentifier where navigator === self.navigator:
            let controller = ChanningTabBarController(navigatorDelegate: self, appRouter: self)
            activeHiddenAppController = controller
            return .acceptCustom(controller)
        case GalleryTabBarController.pathConfigurationIdentifier where navigator === self.navigator:
            let controller = GalleryTabBarController(navigatorDelegate: self, appRouter: self)
            activeHiddenAppController = controller
            return .acceptCustom(controller)

        default:
            return .accept
        }
    }

    func openHiddenApp(_ destination: HiddenAppDestination, from controller: UIViewController) {
        guard let url = destination.url else { return }

        if navigator.rootViewController.topViewController === controller {
            navigator.pop(animated: false)
        }

        navigator.route(url)
    }

    func requestDidFinish(at url: URL) {
        guard let hiddenTabBarController = activeHiddenAppController as? HiddenAppTabBarController else { return }

        let visibleURL = hiddenTabBarController.currentVisibleURL ?? url
        guard visibleURL.path == "/" || !isHiddenAppPath(visibleURL) else { return }

        dismissHiddenAppController(hiddenTabBarController)
    }

    private func isHiddenAppPath(_ url: URL) -> Bool {
        url.path.hasPrefix("/channing") || url.path.hasPrefix("/gallery")
    }

    private func dismissHiddenAppAndRouteToMain(_ url: URL) {
        if let activeHiddenAppController {
            dismissHiddenAppController(activeHiddenAppController)
        }

        navigator.route(url)
    }

    private func dismissHiddenAppController(_ controller: UIViewController) {
        if let hiddenTabBarController = controller as? HiddenAppTabBarController {
            hiddenTabBarController.setHiddenAppTabBarHidden(true)
        }

        navigator.rootViewController.popToRootViewController(animated: false)
        activeHiddenAppController = nil
    }
}
