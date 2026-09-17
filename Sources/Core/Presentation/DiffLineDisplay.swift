import Foundation

public enum DiffLineDisplay {
    public static let limit = 2_000

    public static func text(_ line: String) -> String {
        guard line.utf8.count > limit else { return line }
        let shown = line.prefix(limit)
        guard shown.endIndex < line.endIndex else { return line }
        return String(shown) + omission(bytes: line.utf8.count - shown.utf8.count)
    }

    static func omission(bytes: Int) -> String {
        " … " + ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
            + " more on this line, not shown"
    }
}
