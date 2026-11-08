import Foundation

public enum BridgeProfileTrouble: Error, Sendable, Equatable {
    case notText
    case unreachable(given: String)
    case ambiguous(given: String, ids: [String])

    public var sentence: String {
        switch self {
        case .notText:
            return "'profile' takes a string: a profile's id, or a name no other profile shares."

        case .unreachable(let given):
            return """
                This connection cannot reach a profile called '\(WorkspaceMessage.oneLine(given))'. \
                Unified Dev does not say whether one exists. Retrying will not change that.
                """

        case let .ambiguous(given, ids):
            return """
                More than one profile is called '\(WorkspaceMessage.oneLine(given))', so Unified Dev \
                will not guess which you meant. Pass one of these ids instead: \
                \(BridgeWorkspaceLookup.list(ids)).
                """
        }
    }
}
