import Foundation

public enum WorkspaceDiffTrouble: Error, Sendable, Equatable {
    case target(BridgeReadTrouble)
    case callerHasGone
    case worktreeGone(workspace: String)
    case pathNotText
    case noSuchPath(String, workspace: String)
    case badCursor
    case staleCursor
    case gitFailed(workspace: String, String)
    case unexplained(String)

    public var sentence: String {
        switch self {
        case .target(let trouble):
            return trouble.sentence(tool: WorkspaceDiffTool.name)

        case .callerHasGone:
            return """
                Unified Dev no longer has the workspace this connection speaks for, so there are no \
                changes to read. Its row has gone, which retrying will not undo.
                """

        case .worktreeGone(let workspace):
            return """
                The worktree for '\(workspace)' is no longer on disk, so there are no changes to \
                read. Retrying will not help; the owner can restore or archive it in Unified Dev.
                """

        case .pathNotText:
            return "workspace_diff takes 'path' as a string naming one changed file. Leave it out for every file."

        case let .noSuchPath(path, workspace):
            return """
                '\(path)' is not among the files changed in '\(workspace)'. Call workspace_diff \
                without 'path' and pass a path from its file list.
                """

        case .badCursor:
            return "'cursor' must be a next_cursor returned for this workspace. Omit it to start again."

        case .staleCursor:
            return """
                That cursor does not match these changes: it was returned for another path, or the \
                workspace's changes have moved since. Omit 'cursor' to read them from the start.
                """

        case let .gitFailed(workspace, message):
            return "Unified Dev could not read the changes in '\(workspace)' from git: \(message)"

        case .unexplained(let message):
            return "Unified Dev could not complete workspace_diff: \(message)"
        }
    }
}
