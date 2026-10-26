import Testing
import Foundation
@testable import Core

@Suite("Agent account store", .tags(.persistence), .scratchDirectory)
struct AgentAccountStoreTests {
    private let work = AgentAccountRow(
        id: AgentAccountID("work"), provider: .claudeCode,
        directory: "/accounts/claudeCode/work", label: "Work",
        createdAt: Date(timeIntervalSince1970: 1_000)
    )

    private func seed(_ store: Store) async throws -> (repo: Repo, workspace: Workspace, session: Session) {
        let repo = try await store.upsert(Repo(name: "r", path: TestScratch.unique("repo")))
        let workspace = try await store.upsert(Workspace(
            repoID: repo.id, name: "w", branch: "feature/w",
            path: TestScratch.unique("worktree"), baseBranch: "main"
        ))
        let session = try await store.upsert(Session(workspaceID: workspace.id))
        return (repo, workspace, session)
    }

    @Test("an account choice on a workspace does not carry back other columns")
    func choiceDoesNotCarryBackOtherColumns() async throws {
        let store = try makeTestStore("accounts")
        let (_, workspace, _) = try await seed(store)
        let stale = try #require(try await store.workspace(id: workspace.id))
        try await store.add(work)

        try await store.update(workspaceID: workspace.id) { $0.colour = "4C8DF6" }
        try await store.update(workspaceID: workspace.id, accountID: work.id)

        let read = try #require(try await store.workspace(id: workspace.id))
        #expect(read.colour == "4C8DF6")
        #expect(read.accountID == work.id)
        #expect(stale.colour == nil)
    }

    @Test("a write from a stale copy cannot undo an account choice")
    func staleWriteCannotUndoTheChoice() async throws {
        let store = try makeTestStore("accounts")
        let (repo, workspace, session) = try await seed(store)
        let staleRepo = repo
        let staleWorkspace = workspace
        let staleSession = session
        try await store.add(work)

        try await store.update(repoID: repo.id, accountID: work.id)
        try await store.update(workspaceID: workspace.id, accountID: work.id)
        try await store.update(sessionID: session.id, accountID: work.id)
        try await store.upsert(staleRepo)
        try await store.upsert(staleWorkspace)
        try await store.upsert(staleSession)

        #expect(try await store.repo(id: repo.id)?.accountID == work.id)
        #expect(try await store.workspace(id: workspace.id)?.accountID == work.id)
        #expect(try await store.session(id: session.id)?.accountID == work.id)
    }

    @Test("an account choice on a session leaves its other columns alone")
    func sessionChoiceLeavesOtherColumns() async throws {
        let store = try makeTestStore("accounts")
        let (_, _, session) = try await seed(store)
        try await store.add(work)

        try await store.update(sessionID: session.id) { $0.title = "renamed" }
        try await store.update(sessionID: session.id, accountID: work.id)

        let read = try #require(try await store.session(id: session.id))
        #expect(read.title == "renamed")
        #expect(read.accountID == work.id)
    }

    @Test("a row created with an account keeps it")
    func newRowCarriesItsAccount() async throws {
        let store = try makeTestStore("accounts")
        try await store.add(work)
        var repo = Repo(name: "r", path: TestScratch.unique("repo"))
        repo.accountID = work.id
        try await store.upsert(repo)

        #expect(try await store.repo(id: repo.id)?.accountID == work.id)
    }

    @Test("forgetting an account leaves the rows that pointed at it without one")
    func forgettingLeavesRowsWithoutAccount() async throws {
        let store = try makeTestStore("accounts")
        let (repo, workspace, session) = try await seed(store)
        try await store.add(work)
        try await store.update(repoID: repo.id, accountID: work.id)
        try await store.update(workspaceID: workspace.id, accountID: work.id)
        try await store.update(sessionID: session.id, accountID: work.id)

        try await store.forgetAgentAccount(work.id)

        #expect(try await store.repo(id: repo.id)?.accountID == nil)
        #expect(try await store.workspace(id: workspace.id)?.accountID == nil)
        #expect(try await store.session(id: session.id)?.accountID == nil)
        #expect(try await store.agentAccounts().isEmpty)
    }

    @Test("forgetting one account leaves the rows pointing at another")
    func forgettingLeavesOtherAccounts() async throws {
        let store = try makeTestStore("accounts")
        let (repo, workspace, _) = try await seed(store)
        let personal = AgentAccountRow(id: AgentAccountID("personal"), provider: .codex, directory: "/p")
        try await store.add(work)
        try await store.add(personal)
        try await store.update(repoID: repo.id, accountID: work.id)
        try await store.update(workspaceID: workspace.id, accountID: personal.id)

        try await store.forgetAgentAccount(work.id)

        #expect(try await store.repo(id: repo.id)?.accountID == nil)
        #expect(try await store.workspace(id: workspace.id)?.accountID == personal.id)
        #expect(try await store.agentAccounts().map(\.id) == [personal.id])
    }

    @Test("an account choice clears when set to nil")
    func choiceClearsWhenSetToNil() async throws {
        let store = try makeTestStore("accounts")
        let (repo, _, _) = try await seed(store)
        try await store.add(work)
        try await store.update(repoID: repo.id, accountID: work.id)

        try await store.update(repoID: repo.id, accountID: nil)

        #expect(try await store.repo(id: repo.id)?.accountID == nil)
    }

    @Test("an account that was never added cannot be chosen")
    func unknownAccountIsRefused() async throws {
        let store = try makeTestStore("accounts")
        let (repo, _, _) = try await seed(store)

        await #expect(throws: (any Error).self) {
            try await store.update(repoID: repo.id, accountID: AgentAccountID("missing"))
        }
        #expect(try await store.repo(id: repo.id)?.accountID == nil)
    }

    @Test("an account keeps every column it was added with")
    func accountRoundTrips() async throws {
        let store = try makeTestStore("accounts")
        let standard = AgentAccountRow(
            id: AgentAccountHome.defaultID(for: .codex), provider: .codex,
            directory: "/home/.codex", isDefault: true,
            createdAt: Date(timeIntervalSince1970: 500)
        )
        try await store.add(work)
        try await store.add(standard)

        let read = try await store.agentAccounts()

        #expect(read == [standard, work])
        #expect(read.first?.id.rawValue == "default.codex")
    }

    @Test("adding an account that already exists is refused rather than overwritten")
    func addingTwiceIsRefused() async throws {
        let store = try makeTestStore("accounts")
        try await store.add(work)
        var renamed = work
        renamed.label = "Renamed"

        await #expect(throws: (any Error).self) { try await store.add(renamed) }
        #expect(try await store.agentAccounts().first?.label == "Work")
    }

    @Test("reopening a migrated database is harmless")
    func reopeningIsHarmless() async throws {
        let path = TestScratch.unique("accounts-reopen") + ".sqlite"
        _ = try Store(path: path)

        let reopened = try Store(path: path)

        #expect(try await reopened.agentAccounts().isEmpty)
    }

    @Test("the account migration survives being replayed, and keeps what was stored")
    func migrationReplays() async throws {
        let path = TestScratch.unique("accounts-replay") + ".sqlite"
        let store = try Store(path: path)
        let (repo, _, _) = try await seed(store)
        try await store.add(work)
        try await store.update(repoID: repo.id, accountID: work.id)

        let raw = try SQLiteDatabase(path: path)
        try raw.setUserVersion(0)

        let reopened = try Store(path: path)
        #expect(try await reopened.agentAccounts() == [work])
        #expect(try await reopened.repo(id: repo.id)?.accountID == work.id)
    }
}
