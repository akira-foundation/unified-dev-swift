import Foundation

public enum WorkSuggestionSidebarMark {
    public static let symbol = "lightbulb"

    public static func label(undecided: Int) -> String? {
        guard undecided > 0 else { return nil }
        return Counted.of(undecided, "suggestion") + " to decide"
    }
}
