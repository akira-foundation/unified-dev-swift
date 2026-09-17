import Foundation

public enum LocalPage {
    public static let extensions: Set<String> = ["html", "htm", "svg"]

    public static func isPage(path: String) -> Bool {
        extensions.contains((path as NSString).pathExtension.lowercased())
    }

    public static func canOpen(file path: String) -> Bool {
        guard isPage(path: path) else { return false }
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) else {
            return false
        }
        return !isDirectory.boolValue
    }

    public static func address(forFile path: String) -> String? {
        guard canOpen(file: path) else { return nil }
        return URL(filePath: path).absoluteString
    }

    public static func fileURL(from address: String, root: String) -> URL? {
        let trimmed = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !root.isEmpty, trimmed.hasPrefix("file://"),
              let url = URL(string: trimmed), url.isFileURL
        else { return nil }

        return ContainedPath.resolve(url, inside: URL(filePath: root, directoryHint: .isDirectory))
    }
}
