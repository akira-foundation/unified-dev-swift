import Foundation
import Testing
@testable import Core

@Suite("A preview scenario that leaves a workspace unread")
struct PreviewScenarioUnreadTests {
    @Test("a workspace reads unread, and is read by default")
    func readsTheFlag() throws {
        let scenario = try PreviewScenario.read(Data(#"""
            {"projects":[{"name":"a","workspaces":[
              {"name":"w","branch":"w","unread":true},
              {"name":"v","branch":"v"}]}]}
            """#.utf8))
        let workspaces = scenario.projects[0].workspaces

        #expect(workspaces[0].unread)
        #expect(!workspaces[1].unread)
    }
}

@Suite("Seeding an unread workspace", .tags(.git, .subprocess), .scratchDirectory, .timeLimit(.minutes(1)))
struct PreviewScenarioUnreadSeedingTests {
    @Test("the workspace is stored unread after its chats are written, and the others are not")
    func storesTheFlag() async throws {
        let root = TestScratch.unique("preview-unread")
        let manager = WorkspaceManager(
            store: try makeTestStore("preview-unread"),
            workspacesRoot: URL(fileURLWithPath: root + "/workspaces", isDirectory: true)
        )
        let seeder = PreviewScenarioSeeder(manager: manager, scratchRoot: PreviewIdentity.scratch(in: root))
        _ = try await seeder.seed(PreviewScenario(projects: [
            PreviewScenario.Project(name: "ledger", workspaces: [
                PreviewScenario.Workspace(
                    name: "Read me",
                    branch: "read-me",
                    chats: [PreviewScenario.Chat(title: "Plan", messages: [
                        PreviewScenario.Line(from: .agent, text: "Done."),
                    ])],
                    unread: true
                ),
                PreviewScenario.Workspace(name: "Quiet", branch: "quiet"),
            ]),
        ]))

        let repo = try #require(try await manager.store.repos().first)
        let workspaces = try await manager.store.workspaces(repoID: repo.id)
        let unread = try #require(workspaces.first { $0.branch == "read-me" })
        let quiet = try #require(workspaces.first { $0.branch == "quiet" })

        #expect(unread.unread)
        #expect(!quiet.unread)
    }
}
