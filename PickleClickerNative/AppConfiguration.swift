import Foundation

enum AppConfiguration {
    static let defaultBaseURL = "http://localhost:3000"

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
}
