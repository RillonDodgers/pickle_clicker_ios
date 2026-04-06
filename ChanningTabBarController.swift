import HotwireNative
import UIKit
import WebKit

enum HiddenAppDestination: String, CaseIterable {
    case channing
    case gallery
    case tumblr

    var title: String {
        switch self {
        case .channing:
            return "Channing"
        case .gallery:
            return "Gallery"
        case .tumblr:
            return "Tumblr"
        }
    }

    var url: URL? {
        switch self {
        case .channing:
            return AppConfiguration.baseURL.appendingPathComponent("channing")
        case .gallery:
            return AppConfiguration.baseURL.appendingPathComponent("gallery")
        case .tumblr:
            return nil
        }
    }
}

protocol HiddenAppRouting: AnyObject {
    func openHiddenApp(_ destination: HiddenAppDestination, from controller: UIViewController)
}

class HiddenAppTabBarController: HotwireTabBarController, UITabBarControllerDelegate {
    private let appTabs: [HotwireTab]
    private let currentApp: HiddenAppDestination
    private weak var appRouter: HiddenAppRouting?
    private let drawerTabIndex: Int
    private let initialSelectedIndex: Int

    init(
        currentApp: HiddenAppDestination,
        tabs: [HotwireTab],
        initialSelectedIndex: Int = 0,
        navigatorDelegate: NavigatorDelegate? = nil,
        appRouter: HiddenAppRouting? = nil
    ) {
        self.currentApp = currentApp
        self.appTabs = tabs
        self.initialSelectedIndex = initialSelectedIndex
        self.drawerTabIndex = tabs.count - 1
        self.appRouter = appRouter
        super.init(navigatorDelegate: navigatorDelegate)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        mode = .tabBar
        tabBarMinimizeBehavior = .never
        view.backgroundColor = UIColor(red: 10.0 / 255.0, green: 10.0 / 255.0, blue: 11.0 / 255.0, alpha: 1.0)
        delegate = self
        configureAppearance()
        load(appTabs)
        selectedIndex = initialSelectedIndex

        viewControllers?.forEach { controller in
            if let navigationController = controller as? UINavigationController {
                navigationController.setNavigationBarHidden(true, animated: false)
            }
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        let safeAreaBottom = view.safeAreaInsets.bottom
        let targetHeight = 48.0 + safeAreaBottom
        var frame = tabBar.frame
        if abs(frame.height - targetHeight) > 0.5 {
            frame.size.height = targetHeight
            frame.origin.y = view.bounds.height - targetHeight
            tabBar.frame = frame
        }
    }

    func setHiddenAppTabBarHidden(_ hidden: Bool) {
        tabBar.isHidden = hidden
    }

    var currentVisibleURL: URL? {
        activeNavigator.activeWebView.url
    }

    func tabBarController(_ tabBarController: UITabBarController, shouldSelect viewController: UIViewController) -> Bool {
        guard let viewControllers,
              let tappedIndex = viewControllers.firstIndex(of: viewController),
              tappedIndex == drawerTabIndex else {
            return true
        }

        presentAppDrawer()
        return false
    }

    private func presentAppDrawer() {
        let sheet = UIAlertController(title: "Apps", message: nil, preferredStyle: .actionSheet)

        HiddenAppDestination.allCases.forEach { destination in
            let action = UIAlertAction(title: destination.title, style: .default) { [weak self] _ in
                guard let self else { return }
                self.appRouter?.openHiddenApp(destination, from: self)
            }
            action.isEnabled = destination.url != nil && destination != currentApp
            sheet.addAction(action)
        }

        sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(sheet, animated: true)
    }

    private func configureAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        let backgroundColor = UIColor(red: 17.0 / 255.0, green: 17.0 / 255.0, blue: 20.0 / 255.0, alpha: 1.0)
        appearance.backgroundColor = backgroundColor
        appearance.backgroundEffect = nil
        appearance.shadowColor = UIColor(white: 1.0, alpha: 0.08)
        appearance.stackedLayoutAppearance.normal.iconColor = UIColor(white: 0.72, alpha: 1.0)
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor(white: 0.72, alpha: 1.0)]
        appearance.stackedLayoutAppearance.selected.iconColor = .white
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: UIColor.white]

        tabBar.standardAppearance = appearance
        if #available(iOS 15.0, *) {
            tabBar.scrollEdgeAppearance = appearance
        }

        tabBar.selectionIndicatorImage = UIImage()
        tabBar.itemPositioning = .fill
        tabBar.tintColor = .white
        tabBar.unselectedItemTintColor = UIColor(white: 0.72, alpha: 1.0)
        tabBar.isTranslucent = false
        tabBar.barTintColor = backgroundColor
        tabBar.backgroundColor = backgroundColor
        tabBar.backgroundImage = UIImage()
        tabBar.shadowImage = UIImage()
    }
}

final class ChanningTabBarController: HiddenAppTabBarController, PathConfigurationIdentifiable {
    static let pathConfigurationIdentifier = "channing_tabs"

    init(navigatorDelegate: NavigatorDelegate? = nil, appRouter: HiddenAppRouting? = nil) {
        let tabs = [
            HotwireTab(
                title: "Boards",
                image: UIImage(systemName: "list.bullet")!,
                url: AppConfiguration.baseURL.appendingPathComponent("channing")
            ),
            HotwireTab(
                title: "Settings",
                image: UIImage(systemName: "gearshape")!,
                url: AppConfiguration.baseURL.appendingPathComponent("channing/settings")
            ),
            HotwireTab(
                title: "Apps",
                image: UIImage(systemName: "square.grid.2x2")!,
                url: AppConfiguration.baseURL.appendingPathComponent("channing")
            )
        ]

        super.init(
            currentApp: .channing,
            tabs: tabs,
            navigatorDelegate: navigatorDelegate,
            appRouter: appRouter
        )
    }
}

final class GalleryTabBarController: HiddenAppTabBarController, PathConfigurationIdentifiable {
    static let pathConfigurationIdentifier = "gallery_tabs"

    init(navigatorDelegate: NavigatorDelegate? = nil, appRouter: HiddenAppRouting? = nil) {
        let tabs = [
            HotwireTab(
                title: "Albums",
                image: UIImage(systemName: "rectangle.stack")!,
                url: AppConfiguration.baseURL.appendingPathComponent("gallery")
            ),
            HotwireTab(
                title: "Photos",
                image: UIImage(systemName: "photo.on.rectangle")!,
                url: AppConfiguration.baseURL.appendingPathComponent("gallery/photos")
            ),
            HotwireTab(
                title: "Settings",
                image: UIImage(systemName: "gearshape")!,
                url: AppConfiguration.baseURL.appendingPathComponent("gallery/settings")
            ),
            HotwireTab(
                title: "Apps",
                image: UIImage(systemName: "square.grid.2x2")!,
                url: AppConfiguration.baseURL.appendingPathComponent("gallery")
            )
        ]

        super.init(
            currentApp: .gallery,
            tabs: tabs,
            navigatorDelegate: navigatorDelegate,
            appRouter: appRouter
        )
    }
}
