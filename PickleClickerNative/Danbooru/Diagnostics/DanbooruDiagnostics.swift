import Foundation
import OSLog

enum DanbooruDiagnostics {
    static let subsystem = "PickleClickerNative.Danbooru"
    static let app = Logger(subsystem: subsystem, category: "app")
    static let network = Logger(subsystem: subsystem, category: "network")
    static let ui = Logger(subsystem: subsystem, category: "ui")
    static let state = Logger(subsystem: subsystem, category: "state")
}
