import Testing
import Foundation
@testable import Core

@Suite("Agent account resolver", .tags(.persistence), .scratchDirectory)
struct AgentAccountResolverTests {
    private let user = URL(filePath: "/Users/someone")

    private var defaultClaude: AgentAccountHome { AgentAccountHome.defaultHome(for: .claudeCode, home: user)! }
    private var defaultCodex: AgentAccountHome { AgentAccountHome.defaultHome(for: .codex, home: user)! }

    private func accountDirectory(_ name: String) throws -> String {
        let path = TestScratch.unique("accounts") + "/" + name
        try FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true)
        return path
    }

    private func seed(_ store: Store) async throws -> (repo: Repo, workspace: Workspace) {
        let repo = try await store.upsert(Repo(name: "r", path: TestScratch.unique("repo")))
        let workspace = try await store.upsert(Workspace(
            repoID: repo.id, name: "w", branch: "feature/w",
            path: TestScratch.unique("worktree"), baseBranch: "main"
        ))
        return (repo, workspace)
    }

    @Test func nothingChosenResolvesToTheDefaultAccount() async throws {
        let store = try makeTestStore("resolver")
        let (repo, workspace) = try await seed(store)

        let choice = try await AgentAccountResolver.resolve(
            workspaceID: workspace.id, repoID: repo.id, store: store, defaults: [defaultClaude]
        ).choice(for: .claudeCode)

        #expect(choice.home?.id == defaultClaude.id)
        #expect(choice.reason == .providerDefault)
    }

    @Test func theChoiceIsReadFromTheStoreAtTheMomentOfAskingNotFromACopy() async throws {
        let store = try makeTestStore("resolver")
        let (repo, workspace) = try await seed(store)
        let work = AgentAccountRow(
            id: AgentAccountID("work"), provider: .claudeCode, directory: try accountDirectory("work")
        )
        try await store.add(work)

        let before = try await AgentAccountResolver.resolve(
            workspaceID: workspace.id, repoID: repo.id, store: store, defaults: [defaultClaude]
        ).choice(for: .claudeCode)
        try await store.chooseAgentAccount(ChosenAgentAccount(AgentAccountHome(work)), forWorkspace: workspace.id)
        let after = try await AgentAccountResolver.resolve(
            workspaceID: workspace.id, repoID: repo.id, store: store, defaults: [defaultClaude]
        ).choice(for: .claudeCode)

        #expect(before.reason == .providerDefault)
        #expect(after.home?.id == work.id)
        #expect(after.reason == .workspace)
        #expect(after.home?.directory.path == work.directory)
    }

    @Test func theProjectChoiceReachesAWorkspaceThatChoseNothing() async throws {
        let store = try makeTestStore("resolver")
        let (repo, workspace) = try await seed(store)
        let work = AgentAccountRow(
            id: AgentAccountID("work"), provider: .claudeCode, directory: try accountDirectory("work")
        )
        try await store.add(work)
        try await store.chooseAgentAccount(ChosenAgentAccount(AgentAccountHome(work)), forRepo: repo.id)

        let choice = try await AgentAccountResolver.resolve(
            workspaceID: workspace.id, repoID: nil, store: store, defaults: [defaultClaude]
        ).choice(for: .claudeCode)

        #expect(choice.home?.id == work.id)
        #expect(choice.reason == .project)
    }

    @Test func anAccountWhoseDirectoryWasDeletedByHandIsLostAndTheDefaultRuns() async throws {
        let store = try makeTestStore("resolver")
        let (_, workspace) = try await seed(store)
        let vanished = AgentAccountRow(
            id: AgentAccountID("vanished"), provider: .claudeCode, directory: TestScratch.unique("vanished")
        )
        try await store.add(vanished)
        try await store.chooseAgentAccount(ChosenAgentAccount(AgentAccountHome(vanished)), forWorkspace: workspace.id)

        let choice = try await AgentAccountResolver.resolve(
            workspaceID: workspace.id, repoID: nil, store: store, defaults: [defaultClaude]
        ).choice(for: .claudeCode)

        #expect(choice.home?.id == defaultClaude.id)
        #expect(choice.lost == [.workspace])
        #expect(!FileManager.default.fileExists(atPath: vanished.directory))
    }

    @Test func eachAgentGetsItsOwnHomeFromOneChoice() async throws {
        let store = try makeTestStore("resolver")
        let (repo, workspace) = try await seed(store)
        let work = AgentAccountRow(
            id: AgentAccountID("work"), provider: .claudeCode, directory: try accountDirectory("work")
        )
        try await store.add(work)
        try await store.chooseAgentAccount(ChosenAgentAccount(AgentAccountHome(work)), forRepo: repo.id)

        let homes = try await AgentAccountResolver.resolve(
            workspaceID: workspace.id, repoID: nil, store: store, defaults: [defaultClaude, defaultCodex]
        ).homes

        #expect(homes[.claudeCode]?.id == work.id)
        #expect(homes[.codex]?.id == defaultCodex.id)
        #expect(homes[.cursor] == nil)
    }

    @Test func noWorkspaceAndNoProjectStillResolvesToTheDefaults() async throws {
        let store = try makeTestStore("resolver")

        let homes = try await AgentAccountResolver.resolve(
            workspaceID: nil, repoID: nil, store: store, defaults: [defaultClaude, defaultCodex]
        ).homes

        #expect(homes[.claudeCode]?.id == defaultClaude.id)
        #expect(homes[.codex]?.id == defaultCodex.id)
    }

    @Test func theLineForAnAgentIsWrittenFromTheSameResolution() async throws {
        let store = try makeTestStore("resolver")
        let (repo, workspace) = try await seed(store)
        let work = AgentAccountRow(
            id: AgentAccountID("work"), provider: .claudeCode, directory: try accountDirectory("work")
        )
        try await store.add(work)
        try await store.chooseAgentAccount(ChosenAgentAccount(AgentAccountHome(work)), forRepo: repo.id)

        let resolution = try await AgentAccountResolver.resolve(
            workspaceID: workspace.id, repoID: nil, store: store, defaults: [defaultClaude, defaultCodex]
        )

        #expect(resolution.line(for: .claudeCode).sentence == "work runs here, chosen for the project.")
        #expect(resolution.line(for: .codex).sentence == "The default account runs here.")
        #expect(!resolution.line(for: .codex).warns)
    }

    @Test func oneScopeResolvesEachAgentToTheAccountChosenForThatAgent() async throws {
        let store = try makeTestStore("resolver")
        let (repo, workspace) = try await seed(store)
        let claude = AgentAccountRow(
            id: AgentAccountID("client-claude"), provider: .claudeCode,
            directory: try accountDirectory("client-claude")
        )
        let codex = AgentAccountRow(
            id: AgentAccountID("client-codex"), provider: .codex,
            directory: try accountDirectory("client-codex")
        )
        try await store.add(claude)
        try await store.add(codex)

        try await store.chooseAgentAccount(ChosenAgentAccount(AgentAccountHome(claude)), forRepo: repo.id)
        try await store.chooseAgentAccount(ChosenAgentAccount(AgentAccountHome(codex)), forRepo: repo.id)

        let homes = try await AgentAccountResolver.resolve(
            workspaceID: workspace.id, repoID: nil, store: store, defaults: [defaultClaude, defaultCodex]
        ).homes

        #expect(homes[.claudeCode]?.id == claude.id)
        #expect(homes[.codex]?.id == codex.id)
    }

    @Test func aWorkspaceChoiceForOneAgentLeavesTheOtherAgentOnTheProjectChoice() async throws {
        let store = try makeTestStore("resolver")
        let (repo, workspace) = try await seed(store)
        let projectCodex = AgentAccountRow(
            id: AgentAccountID("project-codex"), provider: .codex,
            directory: try accountDirectory("project-codex")
        )
        let mine = AgentAccountRow(
            id: AgentAccountID("mine"), provider: .claudeCode, directory: try accountDirectory("mine")
        )
        try await store.add(projectCodex)
        try await store.add(mine)
        try await store.chooseAgentAccount(ChosenAgentAccount(AgentAccountHome(projectCodex)), forRepo: repo.id)

        try await store.chooseAgentAccount(ChosenAgentAccount(AgentAccountHome(mine)), forWorkspace: workspace.id)

        let resolution = try await AgentAccountResolver.resolve(
            workspaceID: workspace.id, repoID: nil, store: store, defaults: [defaultClaude, defaultCodex]
        )

        #expect(resolution.choice(for: .claudeCode).home?.id == mine.id)
        #expect(resolution.choice(for: .claudeCode).reason == .workspace)
        #expect(resolution.choice(for: .codex).home?.id == projectCodex.id)
        #expect(resolution.choice(for: .codex).reason == .project)
        #expect(resolution.choice(for: .codex).lost.isEmpty)
    }

    @Test func thePickerReadsTheSameStoredChoicesTheResolutionWasBuiltFrom() async throws {
        let store = try makeTestStore("resolver")
        let (repo, workspace) = try await seed(store)
        let work = AgentAccountRow(
            id: AgentAccountID("work"), provider: .claudeCode, directory: try accountDirectory("work")
        )
        try await store.add(work)
        try await store.chooseAgentAccount(ChosenAgentAccount(AgentAccountHome(work)), forRepo: repo.id)

        let resolution = try await AgentAccountResolver.resolve(
            workspaceID: workspace.id, repoID: nil, store: store, defaults: [defaultClaude, defaultCodex]
        )

        #expect(resolution.stored.project == [.claudeCode: work.id])
        #expect(resolution.stored.workspace.isEmpty)
        let claude = try #require(resolution.options(.project).groups.first { $0.provider == .claudeCode })
        #expect(claude.selected == .account(work.id))
    }
}
