import Testing
@testable import Core

@Suite("A preview scenario with a hidden project")
struct PreviewScenarioHiddenProjectTests {
    @Test("a hidden project with no workspaces is allowed, because nothing brings it back")
    func hiddenAndEmptyIsAllowed() {
        let scenario = PreviewScenario(projects: [
            PreviewScenario.Project(name: "almanac", hidden: true),
        ])

        #expect(scenario.problems.isEmpty)
    }

    @Test("a hidden project with workspaces is refused, because adding one shows the project again")
    func hiddenWithWorkspacesIsRefused() {
        let scenario = PreviewScenario(projects: [
            PreviewScenario.Project(
                name: "almanac",
                workspaces: [PreviewScenario.Workspace(name: "Tides", branch: "tides")],
                hidden: true
            ),
        ])

        #expect(scenario.problems.count == 1)
        #expect(scenario.problems[0].contains("would not stay hidden"))
    }

    @Test("a project with workspaces that is not hidden is allowed")
    func shownWithWorkspacesIsAllowed() {
        let scenario = PreviewScenario(projects: [
            PreviewScenario.Project(name: "almanac", workspaces: [
                PreviewScenario.Workspace(name: "Tides", branch: "tides"),
            ]),
        ])

        #expect(scenario.problems.isEmpty)
    }
}
