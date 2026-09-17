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
    case childOutOfReach(target: String)
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
            return """
                Unified Dev has no active workspace called '\(given)'. Active workspaces: \
                \(BridgeWorkspaceLookup.list(known)). Retrying with the same name will fail the \
                same way, so pass an id workspace_list reports.
                """

        case let .ambiguous(given, ids):
            return """
                More than one workspace is called '\(given)', so Unified Dev will not guess which you \
                meant. Pass one of these ids instead: \(BridgeWorkspaceLookup.list(ids)).
                """

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

        case .childOutOfReach(let target):
            return """
                Another agent started this workspace, so it may only write to the workspace that \
                started it, or to one that has written to it, and '\(target)' is neither. Say what \
                you need to the workspace that started you, and let it decide.
                """

        case .appRefused(let sentence):
            return "Unified Dev did not deliver it: \(sentence)"

        case .unexplained(let message):
            return "Unified Dev could not complete workspace_say: \(message)"
        }
    }
}
