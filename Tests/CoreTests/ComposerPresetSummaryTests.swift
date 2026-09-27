import Testing
@testable import Core

@Suite("The agent settings button's words")
struct ComposerPresetSummaryTests {
    static let opusHigh = ModelPreset(
        name: "Opus 5 High", model: "opus", effort: "high", backend: .claudeCode,
        permissionMode: .bypassPermissions
    )

    @Test("Settings that are a preset show its name and no dot")
    func matched() {
        let summary = ComposerPresetSummary(
            controls: ComposerControls().applying(Self.opusHigh),
            presets: ModelPresetList(presets: [Self.opusHigh]),
            modelLabel: "Opus", effortLabel: "High"
        )
        #expect(summary.matched == Self.opusHigh)
        #expect(summary.title == "Opus 5 High")
        #expect(!summary.isOneOff)
        #expect(summary.help == "Agent settings, preset Opus 5 High")
        #expect(summary.accessibilityValue == "Opus 5 High: Opus, High, Bypass permissions")
    }

    @Test("Settings that are no saved preset show the model and level, with a dot")
    func oneOff() {
        var controls = ComposerControls().applying(Self.opusHigh)
        controls.effort = "medium"
        let summary = ComposerPresetSummary(
            controls: controls,
            presets: ModelPresetList(presets: [Self.opusHigh]),
            modelLabel: "Opus", effortLabel: "Medium"
        )
        #expect(summary.matched == nil)
        #expect(summary.title == "Opus \u{00B7} Medium")
        #expect(summary.isOneOff)
        #expect(summary.help == "Agent settings")
        #expect(summary.accessibilityValue == "Opus, Medium, Bypass permissions")
        #expect(summary.suggestedName == "Opus Medium")
    }

    @Test("With no presets there is nothing to be a one-off of")
    func noPresets() {
        let summary = ComposerPresetSummary(
            controls: ComposerControls(), presets: ModelPresetList(), modelLabel: "Opus", effortLabel: "High"
        )
        #expect(!summary.isOneOff)
        #expect(summary.title == "Opus \u{00B7} High")
    }

    @Test("The permission mode is named in the words of the agent in use")
    func codexWords() {
        let controls = ComposerControls(
            model: "gpt-5.5", effort: "low", agentKind: .codex, permissionMode: .autoReview
        )
        let summary = ComposerPresetSummary(
            controls: controls, presets: ModelPresetList(), modelLabel: "GPT-5.5", effortLabel: "Low"
        )
        #expect(summary.accessibilityValue == "GPT-5.5, Low, Approve for me")
    }
}
