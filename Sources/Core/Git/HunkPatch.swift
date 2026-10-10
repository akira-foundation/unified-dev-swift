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

        return ([header(old: oldPath, new: newPath), oldPath, newPath] + body)
            .joined(separator: "\n") + "\n"
    }

    public static let wholeFileContext = 1_000_000

    public static func anchor(_ hunk: DiffHunk, in whole: String) -> String? {
        let files = DiffParser.parse(whole)
        guard files.count == 1, let file = files.first, file.hunks.count == 1,
              let merged = file.hunks.first, merged.oldStart <= 1, merged.newStart <= 1
        else { return nil }

        let lines = whole.components(separatedBy: "\n")
        guard let newPath = lines.first(where: { $0.hasPrefix("+++ ") }),
              let oldPath = oldSide(of: newPath),
              let heading = lines.firstIndex(where: { $0.hasPrefix("@@") })
        else { return nil }

        var body = Array(lines[(heading + 1)...])
        if body.last?.isEmpty == true { body.removeLast() }
        guard let region = region(of: hunk, in: body) else { return nil }

        let rewritten = reduce(body, keeping: region)
        let counts = "@@ -\(rewritten.oldStart),\(rewritten.oldCount)"
            + " +\(rewritten.newStart),\(rewritten.newCount) @@"
        return ([header(old: oldPath, new: newPath), oldPath, newPath, counts] + rewritten.body)
            .joined(separator: "\n") + "\n"
    }

    struct Reduced {
        var body: [String] = []
        var oldCount = 0
        var newCount = 0

        var oldStart: Int { oldCount == 0 ? 0 : 1 }
        var newStart: Int { newCount == 0 ? 0 : 1 }
    }

    static func reduce(_ body: [String], keeping region: Range<Int>) -> Reduced {
        var reduced = Reduced()
        var dropped = false
        for (index, line) in body.enumerated() {
            let kept = region.contains(index)
            switch line.first {
            case "\\":
                if !dropped { reduced.body.append(line) }
            case "-":
                dropped = !kept
                if kept {
                    reduced.body.append(line)
                    reduced.oldCount += 1
                }
            case "+":
                dropped = false
                reduced.body.append(kept ? line : " " + line.dropFirst())
                reduced.newCount += 1
                if !kept { reduced.oldCount += 1 }
            default:
                dropped = false
                reduced.body.append(line)
                reduced.oldCount += 1
                reduced.newCount += 1
            }
        }
        return reduced
    }

    static func region(of hunk: DiffHunk, in body: [String]) -> Range<Int>? {
        let wanted = hunk.lines
            .filter { $0.kind != .noNewline }
            .map { mark(of: $0.kind) + $0.text }
        guard !wanted.isEmpty else { return nil }
        let linesAbove = hunk.newCount == 0 ? hunk.newStart : hunk.newStart - 1

        var newSideBefore: [Int] = []
        var seen = 0
        for line in body {
            newSideBefore.append(seen)
            if line.hasPrefix(" ") || line.hasPrefix("+") { seen += 1 }
        }

        var found: Range<Int>?
        for start in body.indices where newSideBefore[start] == linesAbove {
            var index = start
            var position = 0
            while index < body.count, position < wanted.count {
                if body[index].hasPrefix("\\") {
                    index += 1
                    continue
                }
                guard body[index] == wanted[position] else { break }
                index += 1
                position += 1
            }
            guard position == wanted.count else { continue }
            if index < body.count, body[index].hasPrefix("\\") { index += 1 }
            guard found == nil else { return nil }
            found = start..<index
        }
        return found
    }

    static func mark(of kind: DiffLine.Kind) -> String {
        switch kind {
        case .context: " "
        case .addition: "+"
        case .deletion: "-"
        case .noNewline: "\\ "
        }
    }

    static func header(old: String, new: String) -> String {
        "diff --git " + name(of: old, after: "--- ") + " " + name(of: new, after: "+++ ")
    }

    static func name(of line: String, after marker: String) -> String {
        var name = Substring(line.dropFirst(marker.count))
        while name.hasSuffix("\t") { name = name.dropLast() }
        return String(name)
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
