import Foundation

public enum WorkspaceSayTrouble: Error, Sendable, Equatable {
    case noMessage
    case tooLong(count: Int)
    case noWorkspace
    case unknown(given: String, known: [String])
    case ambiguous(given: String, ids: [String])
    case archived(name: String)
    case toItself
    case callerHasGone
    case appRefused(String)
    case unexplained(String)

    public var sentence: String {
        switch self {
        case .noMessage:
            return "workspace_say needs a 'message' to send and it cannot be blank."

        case .tooLong(let count):
            return """
                That message is \(count) characters and workspace_say takes up to \
                \(WorkspaceSayTool.maximumLength). Send the other agent what it needs to act on, \
                and point it at files in its own worktree for the rest.
                """

        case .noWorkspace:
            return """
                workspace_say needs the 'workspace' to send it to. Call workspace_list and pass the \
                id it reports, or pass the id named in the message you are answering.
                """

        case let .unknown(given, known):
            return BridgeWorkspaceLookup.unknown(given, known: known)

        case let .ambiguous(given, ids):
            return BridgeWorkspaceLookup.ambiguous(given, ids: ids)

        case .archived(let name):
            return """
                The workspace '\(name)' has been archived, so there is no agent there to send it \
                to. Retrying will not change that.
                """

        case .toItself:
            return """
                That is the workspace you are in. workspace_say is for another workspace; to talk \
                to a subagent in this one, use agent_say.
                """

        case .callerHasGone:
            return """
                Unified Dev no longer has the workspace this connection speaks for, so it cannot say \
                where a message from it came from. Its row has gone, which retrying will not undo.
                """

        case .appRefused(let sentence):
            return "Unified Dev did not deliver it: \(sentence)"

        case .unexplained(let message):
            return "Unified Dev could not complete workspace_say: \(message)"
        }
    }
}
