import Foundation
import Testing
@testable import Core

@Suite("The scenario an agent acts in")
struct BrowserAgentScenarioTests {
    @Test("the acting scenario seeds a form with everything the walkthrough has to provoke")
    func browserAgentActsSeedsAForm() throws {
        let scenario = try TestScenarios.shipped("browser-agent-acts")
        let project = try #require(scenario.projects.first)
        let page = try #require(project.files["form.html"])
        let workspace = try #require(project.workspaces.first)

        #expect(workspace.browser == "http://127.0.0.1:8111/form.html")
        #expect(page.contains("type=\"password\""))
        #expect(page.contains("type=\"checkbox\""))
        #expect(page.contains("disabled"))
        #expect(page.contains("Saved"))
        #expect(page.contains("Spinner"))
        #expect(page.contains("href=\"form.html\""))
    }
}
