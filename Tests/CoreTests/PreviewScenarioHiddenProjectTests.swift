import Foundation
import Testing
@testable import Core

@Suite("Seeding a hidden project", .tags(.git, .subprocess), .scratchDirectory, .timeLimit(.minutes(1)))
struct PreviewScenarioHiddenProjectTests {
    private func seeder(_ name: String) throws -> PreviewScenarioSeeder {
        let root = TestScratch.unique(name)
        let manager = WorkspaceManager(
            store: try makeTestStore(name),
            workspacesRoot: URL(fileURLWithPath: root + "/workspaces", isDirectory: true)
        )
        return PreviewScenarioSeeder(manager: manager, scratchRoot: PreviewIdentity.scratch(in: root))
    }

    @Test("a hidden project keeps its workspaces and stays hidden, because it is hidden after they are cut")
    func hiddenSurvivesItsWorkspaces() async throws {
        let seeder = try seeder("preview-hidden-with-workspaces")
        _ = try await seeder.seed(PreviewScenario(projects: [
            PreviewScenario.Project(
                name: "almanac",
                workspaces: [PreviewScenario.Workspace(name: "Tides", branch: "tides")],
                hidden: true
            ),
        ]))

        let repo = try #require(try await seeder.manager.store.repos().first)
        let workspaces = try await seeder.manager.store.workspaces(repoID: repo.id)

        #expect(repo.hidden)
        #expect(workspaces.map(\.branch) == ["tides"])
    }

    @Test("a project that asks for nothing stays shown")
    func shownStaysShown() async throws {
        let seeder = try seeder("preview-shown-with-workspaces")
        _ = try await seeder.seed(PreviewScenario(projects: [
            PreviewScenario.Project(name: "harbour", workspaces: [
                PreviewScenario.Workspace(name: "Bell", branch: "bell"),
            ]),
        ]))

        let repo = try #require(try await seeder.manager.store.repos().first)

        #expect(!repo.hidden)
    }
}
