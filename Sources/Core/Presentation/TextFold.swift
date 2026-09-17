import Foundation

public enum TextFold {
    public static func title(isExpanded: Bool, lines: Int? = nil) -> String {
        if isExpanded { return "Show less" }
        guard let lines else { return "Show all" }
        return "Show all \(Counted.of(lines, "line"))"
    }
}
