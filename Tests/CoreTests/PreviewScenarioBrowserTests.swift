import Testing
import Foundation
@testable import Core

@Suite("A preview scenario that opens a browser tab")
struct PreviewScenarioBrowserTests {
    @Test("a workspace may name a page to open in a browser tab, and opens none by default")
    func readsTheBrowserPage() throws {
        let scenario = try PreviewScenario.read(Data(#"""
            {"projects":[{"name":"a","workspaces":[
              {"name":"w","branch":"w","browser":"https://example.com/"},
              {"name":"v","branch":"v"}]}]}
            """#.utf8))
        #expect(scenario.projects[0].workspaces.map(\.browser) == ["https://example.com/", nil])
    }

    @Test("a browser page that is not an address is refused before anything is made")
    func refusesAnUnusablePage() {
        let scenario = PreviewScenario(projects: [
            PreviewScenario.Project(name: "a", workspaces: [
                PreviewScenario.Workspace(name: "w", branch: "w", browser: "   "),
            ]),
        ])
        #expect(scenario.problems.contains { $0.contains("is not an address") })
    }
}

@Suite("Seeding a scenario's browser tabs", .tags(.git, .subprocess), .scratchDirectory, .timeLimit(.minutes(1)))
struct PreviewScenarioBrowserSeedingTests {
    @Test("each workspace naming a page hands back one browser tab for the app to open")
    func handsBackTheTabs() async throws {
        let root = TestScratch.unique("preview-browser")
        let manager = WorkspaceManager(
            store: try makeTestStore("preview-browser"),
            workspacesRoot: URL(fileURLWithPath: root + "/workspaces", isDirectory: true)
        )
        let seeder = PreviewScenarioSeeder(manager: manager, scratchRoot: PreviewIdentity.scratch(in: root))
        let outcome = try await seeder.seed(PreviewScenario(projects: [
            PreviewScenario.Project(name: "harbour", workspaces: [
                PreviewScenario.Workspace(name: "Lighthouse", branch: "lighthouse", browser: "https://example.com/"),
                PreviewScenario.Workspace(name: "Bell", branch: "bell"),
            ]),
        ]))

        let repo = try #require(try await manager.store.repos().first)
        let lighthouse = try #require(try await manager.store.workspaces(repoID: repo.id).first { $0.branch == "lighthouse" })
        #expect(outcome.browserTabs == [
            PreviewScenarioSeeder.BrowserTab(workspaceID: lighthouse.id, address: "https://example.com/"),
        ])
    }
}
