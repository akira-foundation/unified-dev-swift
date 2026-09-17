import Foundation

public enum AttachmentTrailer {
    public static let singular = "Attached file:"
    public static let plural = "Attached files:"

    public static func compose(text: String, paths: [String]) -> String {
        guard !paths.isEmpty else { return text }

        let header = paths.count == 1 ? singular : plural
        let list = paths.map { "- \($0)" }.joined(separator: "\n")
        let body = text.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !body.isEmpty else { return "\(header)\n\(list)" }
        return "\(body)\n\n\(header)\n\(list)"
    }

    public static func split(_ text: String) -> (body: String, paths: [String]) {
        let lines = text.components(separatedBy: "\n")

        guard let header = lines.lastIndex(where: { $0 == singular || $0 == plural }) else {
            return (text, [])
        }

        let listed = lines[(header + 1)...]
        guard !listed.isEmpty else { return (text, []) }

        var paths: [String] = []
        for line in listed {
            guard line.hasPrefix("- ") else { return (text, []) }
            let path = String(line.dropFirst(2))
            guard !path.isEmpty,
                  path == path.trimmingCharacters(in: .whitespaces) else { return (text, []) }
            paths.append(path)
        }

        guard lines[header] == (paths.count == 1 ? singular : plural) else { return (text, []) }

        let before = lines[..<header]
        guard !before.isEmpty else { return ("", paths) }

        guard before.last == "" else { return (text, []) }
        let body = before.dropLast().joined(separator: "\n")

        guard body == body.trimmingCharacters(in: .whitespacesAndNewlines) else { return (text, []) }
        return (body, paths)
    }
}
