import Testing
import Foundation
@testable import Core

@Suite("Agent account assignment", .tags(.persistence), .scratchDirectory)
struct AgentAccountAssignmentTests {
    private let user = URL(filePath: "/Users/someone")

    private var defaultClaude: AgentAccountHome { AgentAccountHome.defaultHome(for: .claudeCode, home: user)! }

    private var defaultCodex: AgentAccountHome { AgentAccountHome.defaultHome(for: .codex, home: user)! }

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
        let (repo, _) = try await seed(store)

        try await AgentAccountAssignment.choose(ChosenAgentAccount(defaultClaude), forRepo: repo.id, in: store)

        #expect(try await store.agentAccountChoices().repos[repo.id] == [.claudeCode: defaultClaude.id])
        let rows = try await store.agentAccounts()
        #expect(rows.map(\.id) == [defaultClaude.id])
        #expect(rows.first?.isDefault == true)
        #expect(rows.first?.directory == defaultClaude.directory.path)
    }

    @Test func choosingTheDefaultTwiceKeepsOneRow() async throws {
        let store = try makeTestStore("assignment")
        let (repo, _) = try await seed(store)

        try await AgentAccountAssignment.choose(ChosenAgentAccount(defaultClaude), forRepo: repo.id, in: store)
        try await AgentAccountAssignment.choose(ChosenAgentAccount(defaultClaude), forRepo: repo.id, in: store)

        #expect(try await store.agentAccounts().count == 1)
        #expect(try await store.agentAccountChoices().repos[repo.id] == [.claudeCode: defaultClaude.id])
    }

    @Test func choosingNothingClearsTheChoiceAndAddsNoRow() async throws {
        let store = try makeTestStore("assignment")
        let (repo, _) = try await seed(store)
        try await AgentAccountAssignment.choose(ChosenAgentAccount(defaultClaude), forRepo: repo.id, in: store)

        try await AgentAccountAssignment.choose(
            ChosenAgentAccount(inheritedBy: .claudeCode), forRepo: repo.id, in: store
        )

        #expect(try await store.agentAccountChoices().repos[repo.id] == nil)
    }

    @Test func anAccountTheAppMadeIsChosenWithoutTouchingTheRows() async throws {
        let store = try makeTestStore("assignment")
        let (repo, _) = try await seed(store)
        let row = AgentAccountRow(
            id: AgentAccountID("work"), provider: .claudeCode, directory: "/accounts/work",
            createdAt: Date(timeIntervalSince1970: 1_000)
        )
        try await store.add(row)
        let home = AgentAccountHome(
            provider: .claudeCode, id: row.id, directory: URL(filePath: row.directory), isDefault: false
        )

        try await AgentAccountAssignment.choose(ChosenAgentAccount(home), forRepo: repo.id, in: store)

        #expect(try await store.agentAccountChoices().repos[repo.id] == [.claudeCode: row.id])
        #expect(try await store.agentAccounts() == [row])
    }

    @Test func manySimultaneousChoicesOfTheDefaultLeaveOneRowAndNoComplaint() async throws {
        let store = try makeTestStore("assignment")
        let (repo, _) = try await seed(store)
        let home = defaultClaude

        try await withThrowingTaskGroup(of: Void.self) { group in
            for _ in 0..<16 {
                group.addTask {
                    try await AgentAccountAssignment.choose(ChosenAgentAccount(home), forRepo: repo.id, in: store)
                }
            }
            try await group.waitForAll()
        }

        #expect(try await store.agentAccounts().map(\.id) == [home.id])
        let book = try await store.agentAccountChoices()
        #expect(book.repos[repo.id] == [.claudeCode: home.id])
    }

    @Test func aDefaultRowOnceStoredIsIgnoredByTheInventoryInFavourOfTheLiveDefault() async throws {
        let store = try makeTestStore("assignment")
        let (repo, _) = try await seed(store)
        try await AgentAccountAssignment.choose(ChosenAgentAccount(defaultClaude), forRepo: repo.id, in: store)

        let standings = await AgentAccountInventory.standingsWithoutAsking(
            rows: try await store.agentAccounts(), defaults: [defaultClaude]
        )

        #expect(standings.map(\.home.id) == [defaultClaude.id])
    }

    @Test func oneProjectHoldsAChoiceForEveryAgentAtOnce() async throws {
        let store = try makeTestStore("assignment")
        let (repo, _) = try await seed(store)

        try await AgentAccountAssignment.choose(ChosenAgentAccount(defaultClaude), forRepo: repo.id, in: store)
        try await AgentAccountAssignment.choose(ChosenAgentAccount(defaultCodex), forRepo: repo.id, in: store)

        let book = try await store.agentAccountChoices()
        #expect(book.repos[repo.id] == [.claudeCode: defaultClaude.id, .codex: defaultCodex.id])
    }

    @Test func choosingAgainForOneAgentLeavesTheOtherAgentsChoiceAlone() async throws {
        let store = try makeTestStore("assignment")
        let (repo, _) = try await seed(store)
        let work = AgentAccountRow(id: AgentAccountID("work"), provider: .claudeCode, directory: "/accounts/work")
        try await store.add(work)
        let other = AgentAccountHome(
            provider: .claudeCode, id: work.id, directory: URL(filePath: work.directory), isDefault: false
        )

        try await AgentAccountAssignment.choose(ChosenAgentAccount(defaultClaude), forRepo: repo.id, in: store)
        try await AgentAccountAssignment.choose(ChosenAgentAccount(defaultCodex), forRepo: repo.id, in: store)
        try await AgentAccountAssignment.choose(ChosenAgentAccount(other), forRepo: repo.id, in: store)

        #expect(try await store.agentAccountChoices().repos[repo.id]
            == [.claudeCode: work.id, .codex: defaultCodex.id])
    }

    @Test func clearingOneAgentsChoiceLeavesTheOtherAgentsChoiceAlone() async throws {
        let store = try makeTestStore("assignment")
        let (repo, _) = try await seed(store)
        try await AgentAccountAssignment.choose(ChosenAgentAccount(defaultClaude), forRepo: repo.id, in: store)
        try await AgentAccountAssignment.choose(ChosenAgentAccount(defaultCodex), forRepo: repo.id, in: store)

        try await AgentAccountAssignment.choose(
            ChosenAgentAccount(inheritedBy: .claudeCode), forRepo: repo.id, in: store
        )

        #expect(try await store.agentAccountChoices().repos[repo.id] == [.codex: defaultCodex.id])
    }
}

@Suite("What is said when choosing an account cannot be done")
struct AgentAccountAssignmentSentenceTests {
    @Test func aChoiceNeedsAProject() {
        let repo = RepoID("repo")
        #expect(AgentAccountAssignment.target(repoID: nil) == .failure(.init(sentence: "This project is not known.")))
        #expect(AgentAccountAssignment.target(repoID: repo) == .success(repo))
    }

    @Test func theOtherTwoComplaintsNameTheirCause() {
        #expect(AgentAccountAssignment.noDatabase == "Unified Dev has no database open.")
        #expect(AgentAccountAssignment.saveFailure("locked") == "Could not save the account: locked")
    }
}
