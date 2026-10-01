import Foundation

public enum DocumentPreview {
    public static let scheme = "unified-dev-preview"
    static let host = "worktree"

    public static let withheldNames: Set<String> = [".git", ".claude", ".ssh"]

    public static func hasPreview(path: String) -> Bool {
        ["html", "htm"].contains((path as NSString).pathExtension.lowercased())
    }

    public static func root(forFile absolutePath: String, worktree: String?) -> String {
        if let worktree, !worktree.isEmpty,
           ContainedPath.resolve(
               URL(filePath: absolutePath), inside: URL(filePath: worktree, directoryHint: .isDirectory)
           ) != nil {
            return worktree
        }
        if (try? FileManager.default.destinationOfSymbolicLink(atPath: absolutePath)) != nil {
            return URL(filePath: absolutePath).resolvingSymlinksInPath().deletingLastPathComponent().path
        }
        return (absolutePath as NSString).deletingLastPathComponent
    }

    public static func address(forFile absolutePath: String, root: String) -> URL? {
        let rootURL = resolved(root)
        guard let file = ContainedPath.resolve(URL(filePath: absolutePath), inside: rootURL) else { return nil }
        var components = URLComponents()
        components.scheme = scheme
        components.host = host
        components.path = "/" + String(file.path.dropFirst(rootURL.path.count))
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return components.url
    }

    public static func file(for url: URL, root: String) -> URL? {
        guard url.scheme?.lowercased() == scheme,
              url.host(percentEncoded: false)?.lowercased() == host,
              !root.isEmpty else { return nil }
        let relative = url.path(percentEncoded: false)
        guard !relative.contains("\0") else { return nil }
        let rootURL = URL(filePath: root, directoryHint: .isDirectory)
        guard let candidate = ContainedPath.resolve(rootURL.appending(path: relative), inside: rootURL),
              isOffered(candidate, inside: rootURL) else { return nil }
        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: candidate.path, isDirectory: &isDirectory), isDirectory.boolValue {
            guard let index = ContainedPath.resolve(candidate.appending(path: "index.html"), inside: rootURL),
                  isOffered(index, inside: rootURL) else { return nil }
            return index
        }
        return candidate
    }

    public static func worktreePath(of absolutePath: String, worktree: String) -> String {
        let root = resolved(worktree).path
        let prefix = root.hasSuffix("/") ? root : root + "/"
        return absolutePath.hasPrefix(prefix) ? String(absolutePath.dropFirst(prefix.count)) : absolutePath
    }

    static func isOffered(_ file: URL, inside root: URL) -> Bool {
        let relative = String(file.path.dropFirst(root.standardizedFileURL.resolvingSymlinksInPath().path.count))
        return !relative.split(separator: "/").contains { component in
            withheldNames.contains(String(component)) || component.hasPrefix(".env")
        }
    }

    private static func resolved(_ root: String) -> URL {
        URL(filePath: root, directoryHint: .isDirectory).standardizedFileURL.resolvingSymlinksInPath()
    }
}
