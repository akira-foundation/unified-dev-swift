import Foundation

public struct AccountScope: Hashable, Sendable {
    public var workspaceID: WorkspaceID?
    public var repoID: RepoID?

    public static let none = AccountScope()

    public init(workspaceID: WorkspaceID? = nil, repoID: RepoID? = nil) {
        self.workspaceID = workspaceID
        self.repoID = repoID
    }
}

public struct AccountFingerprint: Hashable, Sendable {
    public var scope: AccountScope
    public var workspace: AgentAccountID?
    public var project: AgentAccountID?

    public init(scope: AccountScope, workspace: AgentAccountID?, project: AgentAccountID?) {
        self.scope = scope
        self.workspace = workspace
        self.project = project
    }

    public static func make(scope: AccountScope, workspace: Workspace?, project: Repo?) -> AccountFingerprint {
        AccountFingerprint(scope: scope, workspace: workspace?.accountID, project: project?.accountID)
    }
}
