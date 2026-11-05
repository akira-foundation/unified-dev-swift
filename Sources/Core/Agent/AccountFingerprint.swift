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
    public var choices: AgentAccountChoices

    public init(scope: AccountScope, choices: AgentAccountChoices) {
        self.scope = scope
        self.choices = choices
    }

    public static func make(
        scope: AccountScope,
        book: AgentAccountChoiceBook,
        repoID: RepoID?
    ) -> AccountFingerprint {
        AccountFingerprint(
            scope: scope,
            choices: book.choices(repoID: scope.repoID ?? repoID)
        )
    }
}
