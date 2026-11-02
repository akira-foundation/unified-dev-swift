import Foundation
import Testing
@testable import Core

@Suite("A preview scenario that pins a workspace or makes one the orchestrator")
struct PreviewScenarioOrchestratorTests {
    @Test("a workspace reads pinned and orchestrator, and is neither by default")
    func readsTheFlags() throws {
        let scenario = try PreviewScenario.read(Data(#"""
            {"projects":[{"name":"a","workspaces":[
              {"name":"lead","branch":"lead","orchestrator":true},
              {"name":"held","branch":"held","pinned":true},
              {"name":"plain","branch":"plain"}]}]}
            """#.utf8))
        let workspaces = scenario.projects[0].workspaces

        #expect(workspaces[0].orchestrator)
        #expect(!workspaces[0].pinned)
        #expect(workspaces[1].pinned)
        #expect(!workspaces[1].orchestrator)
        #expect(!workspaces[2].pinned)
        #expect(!workspaces[2].orchestrator)
        #expect(scenario.problems.isEmpty)
    }

    @Test("a project seeding two orchestrators is refused")
    func refusesTwo() {
        let scenario = PreviewScenario(projects: [
            PreviewScenario.Project(name: "a", workspaces: [
                PreviewScenario.Workspace(name: "one", branch: "one", orchestrator: true),
                PreviewScenario.Workspace(name: "two", branch: "two", orchestrator: true),
            ]),
        ])

        #expect(scenario.problems == ["project \"a\" seeds more than one orchestrator"])
    }

    @Test("two projects may each seed their own orchestrator")
    func allowsOnePerProject() {
        let scenario = PreviewScenario(projects: [
            PreviewScenario.Project(name: "a", workspaces: [
                PreviewScenario.Workspace(name: "one", branch: "one", orchestrator: true),
            ]),
            PreviewScenario.Project(name: "b", workspaces: [
                PreviewScenario.Workspace(name: "two", branch: "two", orchestrator: true),
            ]),
        ])

        #expect(scenario.problems.isEmpty)
    }

    @Test("an orchestrator seeded archived is refused")
    func refusesArchived() {
        let scenario = PreviewScenario(projects: [
            PreviewScenario.Project(name: "a", workspaces: [
                PreviewScenario.Workspace(name: "lead", branch: "lead", orchestrator: true, state: .archived),
            ]),
        ])

        #expect(scenario.problems == [
            "workspace \"lead\" in \"a\" is seeded archived and as the orchestrator, which is never archived",
        ])
    }
}

@Suite("Seeding a pinned workspace and an orchestrator", .tags(.git, .subprocess), .scratchDirectory, .timeLimit(.minutes(1)))
struct PreviewScenarioOrchestratorSeedingTests {
    @Test("the orchestrator and the hand-pinned row are stored as such, and the others are not")
    func storesTheFlags() async throws {
        let root = TestScratch.unique("preview-orchestrator")
        let manager = WorkspaceManager(
            store: try makeTestStore("preview-orchestrator"),
            workspacesRoot: URL(fileURLWithPath: root + "/workspaces", isDirectory: true)
        )
        let seeder = PreviewScenarioSeeder(manager: manager, scratchRoot: PreviewIdentity.scratch(in: root))
        _ = try await seeder.seed(PreviewScenario(projects: [
            PreviewScenario.Project(name: "ledger", workspaces: [
                PreviewScenario.Workspace(name: "Lead", branch: "lead", orchestrator: true),
                PreviewScenario.Workspace(name: "Child", branch: "child", startedBy: "Lead"),
                PreviewScenario.Workspace(name: "Held", branch: "held", pinned: true),
                PreviewScenario.Workspace(name: "Plain", branch: "plain"),
            ]),
        ]))

        let repo = try #require(try await manager.store.repos().first)
        let workspaces = try await manager.store.workspaces(repoID: repo.id)
        let lead = try #require(workspaces.first { $0.branch == "lead" })
        let child = try #require(workspaces.first { $0.branch == "child" })
        let held = try #require(workspaces.first { $0.branch == "held" })
        let plain = try #require(workspaces.first { $0.branch == "plain" })

        #expect(lead.isOrchestrator)
        #expect(lead.pinned)
        #expect(!child.isOrchestrator)
        #expect(!child.pinned)
        #expect(SidebarReorder.isOrchestratorChild(child, among: workspaces))
        #expect(held.pinned)
        #expect(!held.isOrchestrator)
        #expect(!plain.pinned)
        #expect(!plain.isOrchestrator)
    }
    @Test("seeding workspaces beside an orchestrator queues nothing in its chat")
    func seedingAnnouncesNothing() async throws {
        let root = TestScratch.unique("preview-orchestrator-quiet")
        let manager = WorkspaceManager(
            store: try makeTestStore("preview-orchestrator-quiet"),
            workspacesRoot: URL(fileURLWithPath: root + "/workspaces", isDirectory: true)
        )
        let seeder = PreviewScenarioSeeder(manager: manager, scratchRoot: PreviewIdentity.scratch(in: root))
        _ = try await seeder.seed(PreviewScenario(projects: [
            PreviewScenario.Project(name: "ledger", workspaces: [
                PreviewScenario.Workspace(name: "Lead", branch: "lead", orchestrator: true),
                PreviewScenario.Workspace(name: "Plain", branch: "plain"),
            ]),
        ]))

        let repo = try #require(try await manager.store.repos().first)
        let lead = try #require(try await manager.store.workspaces(repoID: repo.id).first { $0.branch == "lead" })
        let leadChats = try await manager.store.sessions(workspaceID: lead.id)
        #expect(!leadChats.isEmpty)
        for chat in leadChats {
            #expect(try await manager.store.pendingDeliveries(sessionID: chat.id).isEmpty)
        }
    }
}
