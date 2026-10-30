import Testing
import Foundation
@testable import Core

@Suite("The move from one account column to a choice per agent", .tags(.persistence), .scratchDirectory)
struct AgentAccountChoiceMigrationTests {
    private let user = URL(filePath: "/Users/someone")

    private var defaultCodex: AgentAccountHome { AgentAccountHome.defaultHome(for: .codex, home: user)! }

    private func columns(_ db: SQLiteDatabase, of table: String) throws -> Set<String> {
        Set(try db.query("PRAGMA table_info(\(table));").compactMap { $0.string("name") })
    }

    private func reinstateOldColumns(_ db: SQLiteDatabase) throws {
        try db.execute("PRAGMA foreign_keys = OFF;")
        for table in AgentAccountChoiceColumns.all {
            try db.execute("DROP TABLE \(table.name);")
            try db.execute("""
                ALTER TABLE \(table.parent)
                ADD COLUMN account_id TEXT REFERENCES agent_accounts(id) ON DELETE SET NULL;
                """)
        }
    }

    private func made(at path: String) async throws -> (repo: Repo, workspace: Workspace) {
        let store = try Store(path: path)
        let repo = try await store.upsert(Repo(name: "r", path: TestScratch.unique("repo")))
        let workspace = try await store.upsert(Workspace(
            repoID: repo.id, name: "w", branch: "b",
            path: TestScratch.unique("worktree"), baseBranch: "main"
        ))
        return (repo, workspace)
    }

    @Test("a choice stored in the old column becomes a choice for that account's own agent")
    func theOldColumnIsCarriedUnderTheAccountsProvider() async throws {
        let path = TestScratch.unique("carry") + ".sqlite"
        let (repo, workspace) = try await made(at: path)
        let claude = AgentAccountRow(id: AgentAccountID("work"), provider: .claudeCode, directory: "/a/work")
        let codex = AgentAccountRow(id: AgentAccountID("lab"), provider: .codex, directory: "/a/lab")
        let seeding = try Store(path: path)
        try await seeding.add(claude)
        try await seeding.add(codex)

        let raw = try SQLiteDatabase(path: path)
        try reinstateOldColumns(raw)
        try raw.run("UPDATE repos SET account_id = ? WHERE id = ?", [.text(claude.id), .text(repo.id)])
        try raw.run(
            "UPDATE workspaces SET account_id = ? WHERE id = ?", [.text(codex.id), .text(workspace.id)]
        )

        let reopened = try Store(path: path)
        let book = try await reopened.agentAccountChoices()

        #expect(book.repos[repo.id] == [.claudeCode: claude.id])
        #expect(book.workspaces[workspace.id] == [.codex: codex.id])
    }

    @Test("the old column is gone once its choices have been carried")
    func theOldColumnIsDropped() async throws {
        let path = TestScratch.unique("drop") + ".sqlite"
        _ = try await made(at: path)
        let raw = try SQLiteDatabase(path: path)
        try reinstateOldColumns(raw)
        #expect(try columns(raw, of: "repos").contains("account_id"))

        _ = try Store(path: path)

        let after = try SQLiteDatabase(path: path)
        #expect(!(try columns(after, of: "repos").contains("account_id")))
        #expect(!(try columns(after, of: "workspaces").contains("account_id")))
        #expect(try columns(after, of: "sessions").contains("account_id"))
    }

    @Test("a default account chosen before it had a row of its own is carried with one")
    func aDefaultChoiceWithNoRowGetsOne() async throws {
        let path = TestScratch.unique("stranger") + ".sqlite"
        let (repo, _) = try await made(at: path)
        let raw = try SQLiteDatabase(path: path)
        try reinstateOldColumns(raw)
        try raw.run(
            "UPDATE repos SET account_id = ? WHERE id = ?",
            [.text(defaultCodex.id), .text(repo.id)]
        )

        try AgentAccountChoiceColumns.migrate(raw, defaults: [defaultCodex])

        let reopened = try Store(path: path)
        #expect(try await reopened.agentAccountChoices().repos[repo.id] == [.codex: defaultCodex.id])
        #expect(try await reopened.agentAccounts().map(\.id) == [defaultCodex.id])
    }

    @Test("a choice naming an account that is not there any more is not carried")
    func aChoiceWithNoAccountIsLeftBehind() async throws {
        let path = TestScratch.unique("ghost") + ".sqlite"
        let (repo, _) = try await made(at: path)
        let raw = try SQLiteDatabase(path: path)
        try reinstateOldColumns(raw)
        try raw.run("UPDATE repos SET account_id = ? WHERE id = ?", [.text("ghost"), .text(repo.id)])

        let reopened = try Store(path: path)

        #expect(try await reopened.agentAccountChoices().repos[repo.id] == nil)
        #expect(try await reopened.agentAccounts().isEmpty)
    }

    @Test("the move survives being replayed over a database it has already moved")
    func theMoveIsIdempotent() async throws {
        let path = TestScratch.unique("replay") + ".sqlite"
        let (repo, _) = try await made(at: path)
        let claude = AgentAccountRow(id: AgentAccountID("work"), provider: .claudeCode, directory: "/a/work")
        let seeding = try Store(path: path)
        try await seeding.add(claude)
        try await seeding.chooseAgentAccount(ChosenAgentAccount(AgentAccountHome(claude)), forRepo: repo.id)

        let raw = try SQLiteDatabase(path: path)
        try raw.setUserVersion(0)
        _ = try Store(path: path)
        let reopened = try Store(path: path)

        #expect(try await reopened.agentAccountChoices().repos[repo.id] == [.claudeCode: claude.id])
        #expect(!(try columns(try SQLiteDatabase(path: path), of: "repos").contains("account_id")))
    }

    @Test("a move that cannot finish carries nothing, so a cleared choice is never resurrected")
    func aMoveThatCannotFinishCarriesNothing() async throws {
        let path = TestScratch.unique("atomic") + ".sqlite"
        let (repo, _) = try await made(at: path)
        let claude = AgentAccountRow(id: AgentAccountID("work"), provider: .claudeCode, directory: "/a/work")
        let seeding = try Store(path: path)
        try await seeding.add(claude)
        let raw = try SQLiteDatabase(path: path)
        try reinstateOldColumns(raw)
        try raw.run("UPDATE repos SET account_id = ? WHERE id = ?", [.text(claude.id), .text(repo.id)])
        try raw.execute("CREATE INDEX repos_account ON repos(account_id);")
        let version = try raw.readUserVersion()

        #expect(throws: (any Error).self) { _ = try Store(path: path) }

        let after = try SQLiteDatabase(path: path)
        #expect(try after.query("SELECT * FROM repo_agent_accounts").isEmpty)
        #expect(try columns(after, of: "repos").contains("account_id"))
        #expect(try after.readUserVersion() == version)

        try after.execute("DROP INDEX repos_account;")
        let reopened = try Store(path: path)
        #expect(try await reopened.agentAccountChoices().repos[repo.id] == [.claudeCode: claude.id])
        #expect(!(try columns(try SQLiteDatabase(path: path), of: "repos").contains("account_id")))
    }

    @Test("the move replays inside the migration transaction when the version says to run it again")
    func theMoveRunsUnderAnOpenTransaction() async throws {
        let path = TestScratch.unique("nested") + ".sqlite"
        let (repo, _) = try await made(at: path)
        let claude = AgentAccountRow(id: AgentAccountID("work"), provider: .claudeCode, directory: "/a/work")
        let seeding = try Store(path: path)
        try await seeding.add(claude)
        let raw = try SQLiteDatabase(path: path)
        try reinstateOldColumns(raw)
        try raw.run("UPDATE repos SET account_id = ? WHERE id = ?", [.text(claude.id), .text(repo.id)])
        try raw.setUserVersion(0)

        let reopened = try Store(path: path)

        #expect(try await reopened.agentAccountChoices().repos[repo.id] == [.claudeCode: claude.id])
        #expect(!(try columns(try SQLiteDatabase(path: path), of: "repos").contains("account_id")))
    }

    @Test("a database with no tables yet is moved on its very first open")
    func aFirstOpenReachesTheMoveBeforeTheTablesExist() async throws {
        let path = TestScratch.unique("first") + ".sqlite"

        let store = try Store(path: path)
        let repo = try await store.upsert(Repo(name: "r", path: TestScratch.unique("repo")))
        let work = AgentAccountRow(id: AgentAccountID("work"), provider: .claudeCode, directory: "/a/work")
        try await store.add(work)
        try await store.chooseAgentAccount(ChosenAgentAccount(AgentAccountHome(work)), forRepo: repo.id)

        #expect(try await store.agentAccountChoices().repos[repo.id] == [.claudeCode: work.id])
    }

    @Test("forgetting an account leaves no choice behind, whichever door the row is deleted through")
    func choicesGoWithTheAccount() async throws {
        let path = TestScratch.unique("cascade") + ".sqlite"
        let (repo, workspace) = try await made(at: path)
        let store = try Store(path: path)
        let work = AgentAccountRow(id: AgentAccountID("work"), provider: .claudeCode, directory: "/a/work")
        try await store.add(work)
        try await store.chooseAgentAccount(ChosenAgentAccount(AgentAccountHome(work)), forRepo: repo.id)
        try await store.chooseAgentAccount(ChosenAgentAccount(AgentAccountHome(work)), forWorkspace: workspace.id)

        let raw = try SQLiteDatabase(path: path)
        try raw.run("DELETE FROM agent_accounts WHERE id = ?", [.text(work.id)])

        let book = try await store.agentAccountChoices()
        #expect(book.repos.isEmpty)
        #expect(book.workspaces.isEmpty)
    }

    @Test("deleting a project takes the accounts chosen for it and its workspaces with it")
    func choicesGoWithTheirOwner() async throws {
        let store = try makeTestStore("owners")
        let repo = try await store.upsert(Repo(name: "r", path: TestScratch.unique("repo")))
        let workspace = try await store.upsert(Workspace(
            repoID: repo.id, name: "w", branch: "b",
            path: TestScratch.unique("worktree"), baseBranch: "main"
        ))
        let work = AgentAccountRow(id: AgentAccountID("work"), provider: .claudeCode, directory: "/a/work")
        try await store.add(work)
        try await store.chooseAgentAccount(ChosenAgentAccount(AgentAccountHome(work)), forRepo: repo.id)
        try await store.chooseAgentAccount(ChosenAgentAccount(AgentAccountHome(work)), forWorkspace: workspace.id)

        try await store.deleteRepo(id: repo.id)

        let book = try await store.agentAccountChoices()
        #expect(book.repos.isEmpty)
        #expect(book.workspaces.isEmpty)
        #expect(try await store.agentAccounts().map(\.id) == [work.id])
    }
}
