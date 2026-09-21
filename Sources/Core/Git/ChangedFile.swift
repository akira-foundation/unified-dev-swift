import Foundation

public struct ChangedFile: Identifiable, Sendable, Hashable {
    public enum Change: String, Sendable {
        case added = "A"
        case modified = "M"
        case deleted = "D"
        case renamed = "R"
        case copied = "C"
        case untracked = "?"
    }

    public var path: String
    public var oldPath: String?
    public var change: Change
    public var additions: Int
    public var deletions: Int
    public var isBinary: Bool

    public var id: String { path }

    public var filename: String { (path as NSString).lastPathComponent }
    public var directory: String { (path as NSString).deletingLastPathComponent }

    public init(
        path: String,
        oldPath: String? = nil,
        change: Change,
        additions: Int = 0,
        deletions: Int = 0,
        isBinary: Bool = false
    ) {
        self.path = path
        self.oldPath = oldPath
        self.change = change
        self.additions = additions
        self.deletions = deletions
        self.isBinary = isBinary
    }
}
