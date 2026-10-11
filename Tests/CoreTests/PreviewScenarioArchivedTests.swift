import Foundation
import Testing
@testable import Core

@Suite("A preview scenario that seeds an archived workspace")
struct PreviewScenarioArchivedTests {
    @Test("a workspace reads its state, and is live by default")
    func readsTheState() throws {
        let scenario = try PreviewScenario.read(Data(#"""
            {"projects":[{"name":"a","workspaces":[
              {"name":"w","branch":"w"},
              {"name":"v","branch":"v","state":"archived"},
              {"name":"u","branch":"u","state":"archivedWithoutBranch"}]}]}
            """#.utf8))
        let workspaces = scenario.projects[0].workspaces

        #expect(workspaces[0].state == .live)
        #expect(!workspaces[0].state.isArchived)
        #expect(workspaces[1].state == .archived)
        #expect(workspaces[1].state.isArchived)
        #expect(workspaces[1].state.keepsItsBranch)
        #expect(workspaces[2].state == .archivedWithoutBranch)
        #expect(workspaces[2].state.isArchived)
        #expect(!workspaces[2].state.keepsItsBranch)
    }

    @Test("an archived workspace cannot also carry work git has never seen")
    func refusesWorkItWouldThrowAway() {
        let withChanges = PreviewScenario(projects: [
            PreviewScenario.Project(name: "atlas", workspaces: [
                PreviewScenario.Workspace(
                    name: "Gone", branch: "gone", changes: ["notes.txt": "unsaved"], state: .archived
                ),
            ]),
        ])
        let withSpares = PreviewScenario(projects: [
            PreviewScenario.Project(name: "atlas", workspaces: [
                PreviewScenario.Workspace(name: "Gone", branch: "gone", spareFiles: 3, state: .archived),
            ]),
        ])

        #expect(withChanges.problems.count == 1)
        #expect(withSpares.problems.count == 1)
    }

    @Test("an archived workspace cannot open a browser tab")
    func refusesABrowserTab() {
        let scenario = PreviewScenario(projects: [
            PreviewScenario.Project(name: "atlas", workspaces: [
                PreviewScenario.Workspace(
                    name: "Gone", branch: "gone", browser: "example.com", state: .archived
                ),
            ]),
        ])

        #expect(scenario.problems.count == 1)
    }

    @Test("the shipped archived selection scenario seeds one live and two archived workspaces")
    func theShippedScenario() throws {
        let scenario = try TestScenarios.shipped("archived-selection")
        let workspaces = try #require(scenario.projects.first).workspaces

        #expect(scenario.problems.isEmpty)
        #expect(workspaces.filter { $0.state == .live }.map(\.name) == ["Dinghy"])
        #expect(workspaces.filter { $0.state == .archived }.map(\.name) == ["Test run"])
        #expect(workspaces.filter { $0.state == .archivedWithoutBranch }.map(\.name) == ["Lighthouse"])
    }
}

@Suite("Seeding an archived workspace", .tags(.git, .subprocess), .scratchDirectory, .timeLimit(.minutes(2)))
struct PreviewScenarioArchivedSeedingTests {
    @Test("the workspace is archived, keeps its chat and loses its worktree")
    func seedsAnArchivedWorkspace() async throws {
        let root = TestScratch.unique("preview-archived")
        let manager = WorkspaceManager(
            store: try makeTestStore("preview-archived"),
            workspacesRoot: URL(fileURLWithPath: root + "/workspaces", isDirectory: true)
        )
        let seeder = PreviewScenarioSeeder(manager: manager, scratchRoot: PreviewIdentity.scratch(in: root))
        let outcome = try await seeder.seed(PreviewScenario(projects: [
            PreviewScenario.Project(name: "atlas", commits: ["Draw the first map"], workspaces: [
                PreviewScenario.Workspace(name: "Dinghy", branch: "dinghy"),
                PreviewScenario.Workspace(
                    name: "Test run",
                    branch: "test-run",
                    chats: [PreviewScenario.Chat(title: "Only chat", messages: [
                        PreviewScenario.Line(from: .user, text: "Does the transcript survive?"),
                        PreviewScenario.Line(from: .agent, text: "It does."),
                    ])],
                    commits: ["Finish the test run"],
                    state: .archived
                ),
                PreviewScenario.Workspace(
                    name: "Lighthouse",
                    branch: "lighthouse",
                    commits: ["Light the lamp"],
                    state: .archivedWithoutBranch
                ),
            ]),
        ]))

        let repo = try #require(try await manager.store.repos().first)
        let rows = try await manager.store.workspaces(repoID: repo.id, includeArchived: true)
        let live = try #require(rows.first { $0.branch == "dinghy" })
        let archived = try #require(rows.first { $0.branch == "test-run" })
        let branchless = try #require(rows.first { $0.branch == "lighthouse" })

        #expect(outcome.archived == 2)
        #expect(live.state == .active)
        #expect(live.archivedAt == nil)
        #expect(archived.state == .archived)
        #expect(archived.archivedAt != nil)
        #expect(branchless.state == .archived)
        #expect(!FileManager.default.fileExists(atPath: archived.path))
        #expect(!FileManager.default.fileExists(atPath: branchless.path))
        #expect(FileManager.default.fileExists(atPath: live.path))
        #expect(await Git.branchExists("test-run", in: repo.path))
        #expect(await !Git.branchExists("lighthouse", in: repo.path))

        let sessions = try await manager.store.sessions(workspaceID: archived.id)
        let session = try #require(sessions.first)
        let messages = try await manager.store.messages(sessionID: session.id)
        #expect(session.title == "Only chat")
        #expect(messages.count == 2)
    }
}
