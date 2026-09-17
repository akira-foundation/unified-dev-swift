import Foundation

public enum TextHead {
    public static let lines = 24
    public static let columns = 160

    public static func head(
        of text: String, lines: Int = TextHead.lines, columns: Int = TextHead.columns
    ) -> (lines: [String], truncated: Bool)? {
        var all = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        while let last = all.last, last.trimmingCharacters(in: .whitespaces).isEmpty {
            all.removeLast()
        }
        guard !all.isEmpty else { return nil }

        let truncated = all.count > lines
        let head = all.prefix(lines).map { line -> String in
            let expanded = line.replacingOccurrences(of: "\t", with: "    ")
            return expanded.count > columns
                ? String(expanded.prefix(columns)) + "\u{2026}"
                : expanded
        }
        return (head, truncated)
    }
}
