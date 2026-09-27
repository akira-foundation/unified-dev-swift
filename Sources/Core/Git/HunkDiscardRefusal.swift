import Foundation

public enum HunkDiscardRefusal: Error, Sendable, Equatable {
    case notOffered
    case changed
    case doesNotApply(String)
}

extension HunkDiscardRefusal: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .notOffered:
            "A single hunk cannot be discarded from this diff."
        case .changed:
            "The file changed since this diff was drawn, so the hunk is not there any more. "
                + "Nothing was discarded."
        case let .doesNotApply(detail):
            "The hunk no longer applies cleanly, so nothing was discarded."
                + (detail.isEmpty ? "" : "\n\n" + detail)
        }
    }
}
