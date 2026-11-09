import Foundation

public struct ComposerDropAnswers: Sendable, Hashable {
    public let items: [ComposerDropItem]
    public let roots: [String]

    public init(items: [ComposerDropItem], roots: [String]) {
        self.items = items
        self.roots = roots
    }
}

public enum ComposerDropQuestions {
    public static let maximumAsked = 256

    public static func answer(
        paths: [String?],
        under root: String,
        isFolder: @escaping @Sendable (String) -> Bool = isFolderOnDisk,
        resolve: @escaping @Sendable (String) -> String = resolvingSymlinks
    ) async -> ComposerDropAnswers {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                continuation.resume(returning: ComposerDropAnswers(
                    items: items(for: paths, isFolder: isFolder),
                    roots: roots(under: root, resolve: resolve)
                ))
            }
        }
    }

    public static func needsAsking(_ paths: [String?]) -> Bool {
        paths.contains { $0 != nil }
    }

    public static func nothingAsked(count: Int) -> ComposerDropAnswers {
        ComposerDropAnswers(items: Array(repeating: .attachment, count: count), roots: [])
    }

    static func items(for paths: [String?], isFolder: (String) -> Bool) -> [ComposerDropItem] {
        var asked = 0
        return paths.map { path in
            guard let path else { return .attachment }
            guard asked < maximumAsked else { return .unasked }
            asked += 1
            return isFolder(path) ? .folder(path) : .attachment
        }
    }

    static func roots(under root: String, resolve: (String) -> String) -> [String] {
        guard !root.isEmpty else { return [] }
        let resolved = resolve(root)
        return resolved == root ? [root] : [root, resolved]
    }

    public static func isFolderOnDisk(_ path: String) -> Bool {
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) && isDirectory.boolValue
    }

    public static func resolvingSymlinks(_ path: String) -> String {
        URL(filePath: path).resolvingSymlinksInPath().path
    }
}
