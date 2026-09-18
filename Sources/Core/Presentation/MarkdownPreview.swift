import Foundation

public enum MarkdownPreview {
    public static func isOffered(path: String, isBinary: Bool, change: ChangedFile.Change) -> Bool {
        Language.detect(path: path) == .markdown && !isBinary && change != .deleted
    }

    public static func isShown(afterToggling shown: Bool, collapsed: Bool) -> Bool {
        collapsed || !shown
    }
}
