import Foundation

public enum InPlaceRename {
    public enum Ending: String, Sendable, CaseIterable {
        case submitted
        case focusLost
        case escaped
        case dismissed
    }

    public enum Outcome: Equatable, Sendable {
        case commit(String)
        case discard
    }

    public static func outcome(_ ending: Ending, draft: String, current: String) -> Outcome {
        guard ending != .escaped else { return .discard }

        let name = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, name != current else { return .discard }
        return .commit(name)
    }
}
