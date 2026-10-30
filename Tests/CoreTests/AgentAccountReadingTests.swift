import Testing
import Foundation
@testable import Core

@MainActor
final class ScanFixture: AccountBound {
    static var built = 0

    let account: AgentAccountID?

    init(account: AgentAccountHome?) {
        self.account = account?.id
        Self.built += 1
    }
}

@Suite("Which selection an account reading belongs to", .tags(.persistence), .scratchDirectory)
struct AgentAccountReadingTests {
    private let work = AccountFixture.work
    private let personal = AccountFixture.personal

    private func made(
        workspace: AgentAccountID? = nil,
        project: AgentAccountID? = nil
    ) -> (scope: AccountScope, workspace: Workspace, project: Repo) {
        var repo = Repo(name: "r", path: "/tmp/r")
        repo.accountID = project
        var space = Workspace(repoID: repo.id, name: "w", branch: "b", path: "/tmp/w", baseBranch: "main")
        space.accountID = workspace
        return (AccountScope(workspaceID: space.id, repoID: repo.id), space, repo)
    }

    @Test func aFingerprintChangesWhenTheWorkspacePicksAnotherAccount() {
        let before = made(workspace: work.id)
        let after = made(workspace: personal.id)

        #expect(AccountFingerprint.make(scope: before.scope, workspace: before.workspace, project: before.project)
            != AccountFingerprint.make(scope: before.scope, workspace: after.workspace, project: after.project))
    }

    @Test func aFingerprintChangesWhenTheProjectPicksAnotherAccount() {
        let before = made(project: work.id)
        let after = made(project: personal.id)

        #expect(AccountFingerprint.make(scope: before.scope, workspace: before.workspace, project: before.project)
            != AccountFingerprint.make(scope: before.scope, workspace: after.workspace, project: after.project))
    }

    @Test func aFingerprintChangesWithTheScopeEvenWhenNothingWasPicked() {
        let one = made()
        let other = made()

        #expect(AccountFingerprint.make(scope: one.scope, workspace: one.workspace, project: one.project)
            != AccountFingerprint.make(scope: other.scope, workspace: other.workspace, project: other.project))
    }

    @Test func theSameSelectionReadTwiceIsTheSameFingerprint() {
        let selection = made(workspace: work.id, project: personal.id)

        #expect(AccountFingerprint.make(
            scope: selection.scope, workspace: selection.workspace, project: selection.project
        ) == AccountFingerprint.make(
            scope: selection.scope, workspace: selection.workspace, project: selection.project
        ))
    }

    @MainActor
    @Test func aStyleCatalogueIsBuiltOncePerProjectAndAccountAndNeverSharedBetweenAccounts() {
        let shelves = OutputStyleShelves<ScanFixture>()
        ScanFixture.built = 0

        let first = shelves.catalogue(project: "/tmp/p", account: work)
        let again = shelves.catalogue(project: "/tmp/p", account: work)
        let other = shelves.catalogue(project: "/tmp/p", account: personal)
        let elsewhere = shelves.catalogue(project: "/tmp/other", account: work)
        let none = shelves.catalogue(project: "/tmp/p", account: nil)

        #expect(first === again)
        #expect(first !== other)
        #expect(first !== elsewhere)
        #expect(first !== none)
        #expect(ScanFixture.built == 4)
        #expect(first.account == work.id)
        #expect(other.account == personal.id)
        #expect(none.account == nil)
    }

    @Test func twoWorkspacesOfOneProjectOnDifferentAccountsDoNotShareAStyleShelf() {
        let home = AgentAccountHome.defaultHome(for: .claudeCode, home: AccountFixture.user)!

        #expect(OutputStyleShelf(project: "/tmp/p", account: work)
            != OutputStyleShelf(project: "/tmp/p", account: personal))
        #expect(OutputStyleShelf(project: "/tmp/p", account: nil)
            != OutputStyleShelf(project: "/tmp/p", account: home))
        #expect(OutputStyleShelf(project: "/tmp/p", account: work)
            == OutputStyleShelf(project: "/tmp/p", account: work))
        #expect(OutputStyleShelf(project: "/tmp/p", account: work)
            != OutputStyleShelf(project: "/tmp/other", account: work))
    }
}
