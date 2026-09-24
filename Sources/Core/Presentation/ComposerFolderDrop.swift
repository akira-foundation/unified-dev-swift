import Foundation

public enum ComposerDropItem: Sendable, Hashable {
    case folder(String)
    case attachment
}

public struct ComposerDropPlan: Sendable, Hashable {
    public let insertion: String
    public let attachmentIndices: [Int]

    public init(insertion: String, attachmentIndices: [Int]) {
        self.insertion = insertion
        self.attachmentIndices = attachmentIndices
    }
}

public enum ComposerFolderDrop {
    public static func plan(_ items: [ComposerDropItem], worktree: String) -> ComposerDropPlan {
        var mentions: [String] = []
        var attachments: [Int] = []
        for (index, item) in items.enumerated() {
            switch item {
            case .folder(let path): mentions.append(mention(of: path, worktree: worktree))
            case .attachment: attachments.append(index)
            }
        }
        let insertion = mentions.isEmpty ? "" : mentions.joined(separator: " ") + " "
        return ComposerDropPlan(insertion: insertion, attachmentIndices: attachments)
    }

    public static func mention(of folder: String, worktree: String) -> String {
        quoted(relative(folder, to: worktree) ?? standardised(folder))
    }

    static func relative(_ folder: String, to worktree: String) -> String? {
        guard !worktree.isEmpty else { return nil }
        let root = standardised(worktree)
        let path = standardised(folder)
        guard path != root else { return "." }
        let prefix = root.hasSuffix("/") ? root : root + "/"
        guard path.hasPrefix(prefix) else { return nil }
        return String(path.dropFirst(prefix.count))
    }

    static func quoted(_ path: String) -> String {
        guard path.contains(where: { $0.isWhitespace || $0 == "\"" }) else { return path }
        let escaped = path
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "\"" + escaped + "\""
    }

    private static func standardised(_ path: String) -> String {
        URL(filePath: path).standardized.path
    }
}
