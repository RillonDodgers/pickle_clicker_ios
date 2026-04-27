import Foundation

enum AppConfiguration {
    static let defaultBaseURL = "https://pickle-clicker.dillonrodgers.party"

    static var baseURL: URL {
        let environment = ProcessInfo.processInfo.environment

        if let configuredURL = environment["PICKLE_CLICKER_BASE_URL"],
           let url = URL(string: configuredURL) {
            return url
        }

        guard let url = URL(string: defaultBaseURL) else {
            fatalError("Invalid default base URL: \(defaultBaseURL)")
        }

        return url
    }

    static var isDeveloperOptionsEnabled: Bool {
        #if DEBUG
        return true
        #else
        let environment = ProcessInfo.processInfo.environment
        let arguments = ProcessInfo.processInfo.arguments
        return environment["PICKLE_CLICKER_DEVELOPER_OPTIONS"] == "1"
            || arguments.contains("--developer-options-enabled")
        #endif
    }
}
