import Foundation

public enum ChangedFileFilter {
    public static func apply(to files: [ChangedFile], needle: String) -> [ChangedFile]? {
        guard !needle.isEmpty else { return nil }
        return files.filter { FileNeedle.matches($0.path, needle: needle) }
    }
}
