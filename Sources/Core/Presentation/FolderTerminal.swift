import Foundation

public enum FolderTerminal {
    public static let menuTitle = "Open Terminal Tab Here"

    public struct Target: Sendable, Equatable {
        public var directory: String
        public var title: String

        public init(directory: String, title: String) {
            self.directory = directory
            self.title = title
        }
    }

    public static func canOpen(folder path: String) -> Bool {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) else {
            return false
        }
        return isDirectory.boolValue
    }

    public static func target(folder path: String, taken: some Sequence<String>) -> Target? {
        guard canOpen(folder: path) else { return nil }
        let name = (path as NSString).lastPathComponent
        let base = name.isEmpty ? PaneNaming.terminal : name
        return Target(directory: path, title: PaneNaming.nextTitle(base: base, taken: taken))
    }

    public static func launchDirectory(requested: String, root: String) -> String {
        guard !requested.isEmpty, canOpen(folder: requested) else { return root }
        return requested
    }
}
