import Foundation

public enum SelectionQuote {
    public static func quote(_ selection: String) -> String? {
        var lines = selection
            .replacingOccurrences(of: "\u{FFFC}", with: "")
            .split(omittingEmptySubsequences: false, whereSeparator: \.isNewline)
            .map { String($0).replacingOccurrences(of: "\\s+$", with: "", options: .regularExpression) }
        while lines.first?.isEmpty == true { lines.removeFirst() }
        while lines.last?.isEmpty == true { lines.removeLast() }
        guard !lines.isEmpty else { return nil }
        let indent = lines.filter { !$0.isEmpty }.map { $0.prefix { $0 == " " || $0 == "\t" }.count }.min() ?? 0
        return lines
            .map { $0.isEmpty ? ">" : "> " + $0.dropFirst(indent) }
            .joined(separator: "\n")
    }

    public static func appending(_ quote: String, to draft: String) -> String {
        var head = draft
        while head.last?.isNewline == true { head.removeLast() }
        return (head.isEmpty ? "" : head + "\n\n") + quote + "\n\n"
    }
}
