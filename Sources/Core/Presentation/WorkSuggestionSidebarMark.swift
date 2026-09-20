import Foundation

public enum WorkSuggestionSidebarMark {
    public struct Destination: Sendable, Hashable {
        public let workspaceID: WorkspaceID
        public let sessionID: SessionID
        public let suggestion: WorkSuggestionID
        public let anchorSeq: Int?
    }

    public static let symbol = "lightbulb"

    public static let openHint = "Opens the chat that made the oldest suggestion still waiting"

    public static func label(undecided: Int) -> String? {
        guard undecided > 0 else { return nil }
        return Counted.of(undecided, "suggestion") + " to decide"
    }

    public static func destination(in suggestions: [WorkSuggestion]) -> Destination? {
        suggestions
            .filter(\.state.isUndecided)
            .min(by: isOlder)
            .flatMap(destination(of:))
    }

    private static func isOlder(_ lhs: WorkSuggestion, _ rhs: WorkSuggestion) -> Bool {
        guard lhs.createdAt == rhs.createdAt else { return lhs.createdAt < rhs.createdAt }
        return (lhs.anchorSeq ?? Int.max) < (rhs.anchorSeq ?? Int.max)
    }

    private static func destination(of suggestion: WorkSuggestion) -> Destination? {
        guard let workspaceID = suggestion.workspaceID else { return nil }
        return Destination(
            workspaceID: workspaceID,
            sessionID: suggestion.sessionID,
            suggestion: suggestion.id,
            anchorSeq: suggestion.anchorSeq
        )
    }
}
