import Foundation

public struct AccountScope: Hashable, Sendable {
    public var workspaceID: WorkspaceID?
    public var repoID: RepoID?
    public var profileID: ProfileID?

    public static let none = AccountScope()

    public init(workspaceID: WorkspaceID? = nil, repoID: RepoID? = nil, profileID: ProfileID? = nil) {
        self.workspaceID = workspaceID
        self.repoID = repoID
        self.profileID = profileID
    }
}

public struct AccountFingerprint: Hashable, Sendable {
    public var scope: AccountScope
    public var choices: AgentAccountChoices
    public var holder: ProfileID?

    public init(scope: AccountScope, choices: AgentAccountChoices, holder: ProfileID? = nil) {
        self.scope = scope
        self.choices = choices
        self.holder = holder
    }

    public static func make(
        scope: AccountScope,
        book: AgentAccountChoiceBook,
        repoID: RepoID?
    ) -> AccountFingerprint {
        let project = scope.repoID ?? repoID
        return AccountFingerprint(
            scope: scope,
            choices: book.choices(repoID: project, profileID: scope.profileID),
            holder: book.profile(of: project, otherwise: scope.profileID).map(book.accounts.holder(for:))
        )
    }
}
