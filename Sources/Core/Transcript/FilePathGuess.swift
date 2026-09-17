import Foundation

public enum FilePathGuess {
    public static let maxLength = 260

    private static let rejected = Set<Character>("*?[]{}|&;<>$\\`()'\"=,:#%!^\n\r\t ")

    public static func isWellFormed(_ path: String) -> Bool {
        guard !path.isEmpty, path.count <= maxLength else { return false }
        return !path.contains(where: \.isNewline)
    }

    public static func looksLikeAFile(_ text: String) -> Bool {
        guard isWellFormed(text) else { return false }
        guard !text.contains("://") else { return false }
        guard !text.contains(where: { rejected.contains($0) }) else { return false }
        guard !text.hasPrefix("-") else { return false }
        guard !text.hasPrefix("~") else { return false }
        guard !text.hasSuffix("/") else { return false }

        let components = text.split(separator: "/", omittingEmptySubsequences: false)
        for (index, component) in components.enumerated() {
            if component.isEmpty {
                guard index == 0, components.count > 1 else { return false }
                continue
            }
            guard component != ".." else { return false }
        }

        guard let name = components.last else { return false }
        return hasExtension(name)
    }

    private static func hasExtension(_ name: Substring) -> Bool {
        guard let dot = name.lastIndex(of: ".") else { return false }

        let stem = name[name.startIndex..<dot]
        guard !stem.isEmpty else { return false }

        let ext = name[name.index(after: dot)...]
        guard (1...8).contains(ext.count) else { return false }
        guard ext.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber) }) else { return false }
        return ext.contains(where: \.isLetter)
    }

    public static func relative(_ path: String, to worktree: String) -> String? {
        guard isWellFormed(path), !worktree.isEmpty else { return nil }

        guard !path.hasPrefix("~") else { return nil }

        guard path.hasPrefix("/") else {
            let trimmed = path.hasPrefix("./") ? String(path.dropFirst(2)) : path
            guard !trimmed.isEmpty, !trimmed.hasPrefix("../") else { return nil }
            return trimmed
        }

        let root = worktree.hasSuffix("/") ? String(worktree.dropLast()) : worktree
        guard path.hasPrefix(root + "/") else { return nil }

        let inside = String(path.dropFirst(root.count + 1))
        return inside.isEmpty ? nil : inside
    }
}
