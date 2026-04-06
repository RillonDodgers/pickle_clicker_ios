import UIKit
import HotwireNative

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        configureHotwire()
        return true
    }

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(
            name: "Default Configuration",
            sessionRole: connectingSceneSession.role
        )
        configuration.delegateClass = SceneDelegate.self
        return configuration
    }

    private func configureHotwire() {
        if let pathConfigurationURL = Bundle.main.url(forResource: "path-configuration", withExtension: "json") {
            Hotwire.loadPathConfiguration(from: [.file(pathConfigurationURL)])
        }

        Hotwire.config.showDoneButtonOnModals = true
    }
}
