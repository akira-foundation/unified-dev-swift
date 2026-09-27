import Foundation

public enum HunkPatch {
    public static func isolate(_ hunk: DiffHunk, from patch: String) -> String? {
        let files = DiffParser.parse(patch)
        guard files.count == 1, let file = files.first else { return nil }
        guard let position = file.hunks.firstIndex(where: { matches($0, hunk) }) else { return nil }

        let lines = patch.components(separatedBy: "\n")
        guard let newPath = lines.first(where: { $0.hasPrefix("+++ ") }),
              let oldPath = oldSide(of: newPath) else { return nil }

        let starts = lines.indices.filter { lines[$0].hasPrefix("@@") }
        guard starts.count == file.hunks.count else { return nil }

        let start = starts[position]
        var end = position + 1 < starts.count ? starts[position + 1] : lines.count
        if end == lines.count, lines.last?.isEmpty == true { end -= 1 }
        let body = lines[start..<end]

        return ([oldPath, newPath] + body).joined(separator: "\n") + "\n"
    }

    static func oldSide(of newPath: String) -> String? {
        let name = newPath.dropFirst("+++ ".count)
        if name.hasPrefix("\"b/") { return "--- \"a/" + name.dropFirst(3) }
        if name.hasPrefix("b/") { return "--- a/" + name.dropFirst(2) }
        return nil
    }

    private static func matches(_ lhs: DiffHunk, _ rhs: DiffHunk) -> Bool {
        lhs.oldStart == rhs.oldStart && lhs.oldCount == rhs.oldCount
            && lhs.newStart == rhs.newStart && lhs.newCount == rhs.newCount
            && lhs.lines.map(\.kind) == rhs.lines.map(\.kind)
            && lhs.lines.map(\.text) == rhs.lines.map(\.text)
    }
}
