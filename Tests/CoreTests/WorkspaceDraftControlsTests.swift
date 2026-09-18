import Foundation
import Testing
@testable import Core

@Suite("The controls a New Workspace draft keeps")
struct WorkspaceDraftControlsTests {
    @Test("the output style, fast mode and context window chosen in the draft reach the workspace")
    func keepsEverySetting() {
        var chosen = ComposerControls(agentKind: .codex, interactionMode: .plan)
        chosen.outputStyle = "Concise"
        chosen.isFastMode = true
        chosen.codexFastMode = false
        chosen.codexContextWindow = 1_000_000
        let kept = WorkspaceDraftControls(chosen, usesCLIChat: false)

        let back = kept.applied(to: ComposerControls())

        #expect(back.outputStyle == "Concise")
        #expect(back.isFastMode)
        #expect(back.codexFastMode == false)
        #expect(back.codexContextWindow == 1_000_000)
        #expect(back.interactionMode == .plan)
    }

    @Test("a draft saved before it kept these settings leaves the defaults in place")
    func olderDraftFallsBackToTheDefaults() throws {
        let stored = #"{"agentKind":"codex","effort":"high","interactionMode":"plan","model":"gpt-5","#
            + #""permissionMode":"auto","usesCLIChat":false}"#
        let kept = try JSONDecoder().decode(WorkspaceDraftControls.self, from: Data(stored.utf8))
        var defaults = ComposerControls()
        defaults.outputStyle = "Explanatory"
        defaults.isFastMode = true
        defaults.codexContextWindow = 1_000_000

        let back = kept.applied(to: defaults)

        #expect(back.model == "gpt-5")
        #expect(back.interactionMode == .plan)
        #expect(back.outputStyle == "Explanatory")
        #expect(back.isFastMode)
        #expect(back.codexContextWindow == 1_000_000)
    }

    @Test("what the draft keeps survives the trip through the database's JSON")
    func roundTripsThroughJSON() throws {
        var chosen = ComposerControls(model: "sonnet")
        chosen.outputStyle = "Concise"
        chosen.isFastMode = true
        let kept = WorkspaceDraftControls(chosen, usesCLIChat: true)

        let data = try JSONEncoder().encode(kept)
        let back = try JSONDecoder().decode(WorkspaceDraftControls.self, from: data)

        #expect(back == kept)
    }
}
