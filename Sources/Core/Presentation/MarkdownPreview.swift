import Foundation

public enum MarkdownPreview {
    public static func isOffered(path: String, isBinary: Bool, change: ChangedFile.Change) -> Bool {
        Language.detect(path: path) == .markdown && !isBinary && change != .deleted
    }
}
