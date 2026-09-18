import Testing
@testable import Core

@Suite("Composer settings label")
struct ComposerSettingsLabelTests {
    @Test func planningIsNamedBesideTheModel() {
        let controls = ComposerControls(agentKind: .codex, interactionMode: .plan)
        #expect(controls.settingsLabel(model: "GPT-5.5") == "GPT-5.5, Plan")
    }

    @Test func buildingShowsTheModelAlone() {
        let controls = ComposerControls(agentKind: .codex, interactionMode: .build)
        #expect(controls.settingsLabel(model: "GPT-5.5") == "GPT-5.5")
    }

    @Test func anAgentWithoutPlanningNeverSaysPlan() {
        var controls = ComposerControls(agentKind: .claudeCode)
        controls.interactionMode = .plan
        #expect(controls.settingsLabel(model: "Opus") == "Opus")
    }
}
