import Testing
import Foundation
@testable import Core

@Suite("Agent account assignment", .tags(.persistence), .scratchDirectory)
struct AgentAccountAssignmentTests {
    private let user = URL(filePath: "/Users/someone")

    private var defaultClaude: AgentAccountHome { AgentAccountHome.defaultHome(for: .claudeCode, home: user)! }

    private func seed(_ store: Store) async throws -> (repo: Repo, workspace: Workspace) {
        let repo = try await store.upsert(Repo(name: "r", path: TestScratch.unique("repo")))
        let workspace = try await store.upsert(Workspace(
            repoID: repo.id, name: "w", branch: "feature/w",
            path: TestScratch.unique("worktree"), baseBranch: "main"
        ))
        return (repo, workspace)
    }

    @Test func choosingTheDefaultAccountAddsItsRowSoTheChoiceCanBeStored() async throws {
        let store = try makeTestStore("assignment")
        let (_, workspace) = try await seed(store)

        try await AgentAccountAssignment.choose(defaultClaude, forWorkspace: workspace.id, in: store)

        #expect(try await store.workspace(id: workspace.id)?.accountID == defaultClaude.id)
        let rows = try await store.agentAccounts()
        #expect(rows.map(\.id) == [defaultClaude.id])
        #expect(rows.first?.isDefault == true)
        #expect(rows.first?.directory == defaultClaude.directory.path)
    }

    @Test func choosingTheDefaultTwiceKeepsOneRow() async throws {
        let store = try makeTestStore("assignment")
        let (repo, workspace) = try await seed(store)

        try await AgentAccountAssignment.choose(defaultClaude, forWorkspace: workspace.id, in: store)
        try await AgentAccountAssignment.choose(defaultClaude, forRepo: repo.id, in: store)

        #expect(try await store.agentAccounts().count == 1)
        #expect(try await store.repo(id: repo.id)?.accountID == defaultClaude.id)
    }

    @Test func choosingNothingClearsTheChoiceAndAddsNoRow() async throws {
        let store = try makeTestStore("assignment")
        let (repo, _) = try await seed(store)
        try await AgentAccountAssignment.choose(defaultClaude, forRepo: repo.id, in: store)

        try await AgentAccountAssignment.choose(nil, forRepo: repo.id, in: store)

        #expect(try await store.repo(id: repo.id)?.accountID == nil)
    }

    @Test func anAccountTheAppMadeIsChosenWithoutTouchingTheRows() async throws {
        let store = try makeTestStore("assignment")
        let (_, workspace) = try await seed(store)
        let row = AgentAccountRow(
            id: AgentAccountID("work"), provider: .claudeCode, directory: "/accounts/work",
            createdAt: Date(timeIntervalSince1970: 1_000)
        )
        try await store.add(row)
        let home = AgentAccountHome(
            provider: .claudeCode, id: row.id, directory: URL(filePath: row.directory), isDefault: false
        )

        try await AgentAccountAssignment.choose(home, forWorkspace: workspace.id, in: store)

        #expect(try await store.workspace(id: workspace.id)?.accountID == row.id)
        #expect(try await store.agentAccounts() == [row])
    }

    @Test func aDefaultRowOnceStoredIsIgnoredByTheInventoryInFavourOfTheLiveDefault() async throws {
        let store = try makeTestStore("assignment")
        let (_, workspace) = try await seed(store)
        try await AgentAccountAssignment.choose(defaultClaude, forWorkspace: workspace.id, in: store)

        let standings = await AgentAccountInventory.standingsWithoutAsking(
            rows: try await store.agentAccounts(), defaults: [defaultClaude]
        )

        #expect(standings.map(\.home.id) == [defaultClaude.id])
    }
}

@Suite("What is said when choosing an account cannot be done")
struct AgentAccountAssignmentSentenceTests {
    @Test func aChoiceThatLacksItsTargetSaysWhichTargetIsNotKnown() {
        #expect(AgentAccountAssignment.projectUnknown == "This project is not known.")
        #expect(AgentAccountAssignment.workspaceUnknown == "This workspace is not known.")
    }

    @Test func theOtherTwoComplaintsNameTheirCause() {
        #expect(AgentAccountAssignment.noDatabase == "Unified Dev has no database open.")
        #expect(AgentAccountAssignment.saveFailure("locked") == "Could not save the account: locked")
    }
}
