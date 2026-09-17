import Foundation

public enum DiffShareText {
    private static let lineBudget = 120
    private static let columnLimit = 200

    public static func make(for file: ChangedFile, diff: FileDiff?) -> String {
        let heading = heading(for: file)

        guard !file.isBinary else {
            return "\(heading)\nBinary file, no text diff."
        }
        guard let diff, !diff.hunks.isEmpty else {
            return "\(heading)\nNo textual changes."
        }

        let (body, omitted) = body(of: diff)
        guard !body.isEmpty else {
            return "\(heading)\nNo textual changes."
        }

        var text = "\(heading)\n```diff\n\(body.joined(separator: "\n"))\n```"
        if omitted > 0 {
            text += "\n\(omitted.formatted()) more \(omitted == 1 ? "line" : "lines") not shown."
        }
        return text
    }

    private static func heading(for file: ChangedFile) -> String {
        let renamedFrom = file.oldPath.flatMap { $0 == file.path ? nil : $0 }
        var parts = [renamedFrom.map { "\($0) -> \(file.path)" } ?? file.path]

        switch file.change {
        case .added, .untracked: parts.append("new file")
        case .deleted: parts.append("deleted")
        case .modified, .renamed, .copied: break
        }

        var counts: [String] = []
        if file.additions > 0 { counts.append("+\(file.additions)") }
        if file.deletions > 0 { counts.append("-\(file.deletions)") }
        if !counts.isEmpty { parts.append(counts.joined(separator: " ")) }

        return parts.joined(separator: "  ")
    }

    private static func body(of diff: FileDiff) -> (lines: [String], omitted: Int) {
        var kept: [String] = []
        var omitted = 0

        for hunk in diff.hunks {
            let rendered = render(hunk)

            if omitted > 0 {
                omitted += rendered.count - 1
                continue
            }
            if kept.isEmpty, rendered.count > lineBudget {
                kept = Array(rendered.prefix(lineBudget))
                omitted = rendered.count - lineBudget
                continue
            }
            guard kept.count + rendered.count <= lineBudget else {
                omitted = rendered.count - 1
                continue
            }
            kept += rendered
        }

        return (kept, omitted)
    }

    private static func render(_ hunk: DiffHunk) -> [String] {
        let start = hunk.newStart > 0 ? hunk.newStart : hunk.oldStart
        var lines = ["@@ line \(start)"]

        for line in hunk.lines {
            switch line.kind {
            case .context: lines.append(" \(clip(line.text))")
            case .addition: lines.append("+\(clip(line.text))")
            case .deletion: lines.append("-\(clip(line.text))")
            case .noNewline: break
            }
        }
        return lines
    }

    private static func clip(_ text: String) -> String {
        guard text.count > columnLimit else { return text }
        return "\(text.prefix(columnLimit))…"
    }
}
