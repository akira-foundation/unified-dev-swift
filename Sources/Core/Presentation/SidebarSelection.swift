import Foundation

public enum SidebarSelection: Hashable, Sendable {
    case home
    case ask
    case workspace(WorkspaceID)
    case archived(WorkspaceID)
    case subagent(WorkspaceID, SubagentID)
    case subagentCall(WorkspaceID, toolUseID: String)
    case crew(WorkspaceID, SessionID)
    case draft(RepoID)

    public var workspaceID: WorkspaceID? {
        switch self {
        case .workspace(let id), .subagent(let id, _), .subagentCall(let id, _), .crew(let id, _): id
        case .home, .ask, .archived, .draft: nil
        }
    }

    public var crewSessionID: SessionID? {
        if case .crew(_, let id) = self { return id }
        return nil
    }

    public var subagentID: SubagentID? {
        if case .subagent(_, let id) = self { return id }
        return nil
    }

    public var archivedWorkspaceID: WorkspaceID? {
        if case .archived(let id) = self { return id }
        return nil
    }

    public var draftRepoID: RepoID? {
        if case .draft(let id) = self { return id }
        return nil
    }
}
