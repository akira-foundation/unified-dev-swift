import Testing
import Foundation
@testable import Core

@Suite("A preview scenario whose workspace was started by another")
struct PreviewScenarioStartedByTests {
    @Test("a workspace reads the workspace that started it, and none by default")
    func readsTheStarter() throws {
        let scenario = try PreviewScenario.read(Data(#"""
            {"projects":[{"name":"a","workspaces":[
              {"name":"Importer","branch":"importer"},
              {"name":"Helper","branch":"helper","startedBy":"Importer"}]}]}
            """#.utf8))
        let workspaces = scenario.projects[0].workspaces

        #expect(workspaces[0].startedBy == nil)
        #expect(workspaces[1].startedBy == "Importer")
    }

    @Test("a starter that is not a workspace listed before it is refused before anything is made", arguments: [
        "Nobody", "Later", "Helper",
    ])
    func refusesAStarterThatIsNotThere(starter: String) {
        let scenario = PreviewScenario(projects: [
            PreviewScenario.Project(name: "a", workspaces: [
                PreviewScenario.Workspace(name: "Helper", branch: "helper", startedBy: starter),
                PreviewScenario.Workspace(name: "Later", branch: "later"),
            ]),
        ])

        #expect(!scenario.problems.isEmpty)
    }

    @Test("a starter in another project is refused, because parentage is seeded inside one project")
    func refusesAStarterInAnotherProject() {
        let scenario = PreviewScenario(projects: [
            PreviewScenario.Project(name: "a", workspaces: [
                PreviewScenario.Workspace(name: "Importer", branch: "importer"),
            ]),
            PreviewScenario.Project(name: "b", workspaces: [
                PreviewScenario.Workspace(name: "Helper", branch: "helper", startedBy: "Importer"),
            ]),
        ])

        #expect(scenario.problems.contains { $0.contains("which is not a workspace listed before it") })
    }

    @Test("the origin names the workspace that started it, and is the owner's own without one")
    func originCarriesTheParent() {
        let parent = WorkspaceID("w-importer")
        let helper = PreviewScenario.Workspace(name: "Helper", branch: "helper", startedBy: "Importer")
        let alone = PreviewScenario.Workspace(name: "Importer", branch: "importer")

        let started = PreviewScenarioSeeder.origin(of: helper, among: ["Importer": parent])
        #expect(started.parentWorkspaceID == parent)
        #expect(started.isAgentSpawned)
        #expect(PreviewScenarioSeeder.origin(of: alone, among: ["Importer": parent]) == .user)
        #expect(PreviewScenarioSeeder.origin(of: helper, among: [:]) == .user)
    }
}
