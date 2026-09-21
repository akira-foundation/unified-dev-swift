import Foundation

public enum BridgeReadTrouble: Error, Sendable, Equatable {
    case notText
    case noWorkspaceNamed
    case unknown(given: String, known: [String])
    case ambiguous(given: String, ids: [String])
    case archived(name: String)

    public func sentence(tool: String) -> String {
        switch self {
        case .notText:
            return "\(tool) takes 'workspace' as a string: a workspace id or name. Leave it out to read your own."

        case .noWorkspaceNamed:
            return """
                \(tool) needs to be told which workspace to read, because this connection is not \
                working in one. Pass 'workspace' with the id workspace_list reports, or a name no \
                other workspace shares.
                """

        case let .unknown(given, known):
            return BridgeWorkspaceLookup.unknown(given, known: known)

        case let .ambiguous(given, ids):
            return BridgeWorkspaceLookup.ambiguous(given, ids: ids)

        case .archived(let name):
            return """
                The workspace '\(name)' has been archived, so \(tool) has nothing there to read. \
                Retrying will not change that.
                """
        }
    }
}
