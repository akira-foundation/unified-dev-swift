import Foundation
import os

enum Log {
    static let archive = Logger(subsystem: subsystem, category: "archive")

    static let composer = Logger(subsystem: subsystem, category: "composer")

    static let ping = Logger(subsystem: subsystem, category: "ping")

    static let updates = Logger(subsystem: subsystem, category: "updates")

    static let crashes = Logger(subsystem: subsystem, category: "crashes")

    static let icons = Logger(subsystem: subsystem, category: "icons")

    static let permissions = Logger(subsystem: subsystem, category: "permissions")

    static let launch = Logger(subsystem: subsystem, category: "launch")

    static let bridge = Logger(subsystem: subsystem, category: "bridge")

    static let runScripts = Logger(subsystem: subsystem, category: "runScripts")

    private static let subsystem = Bundle.main.bundleIdentifier ?? "io.akira.unifieddev"
}
