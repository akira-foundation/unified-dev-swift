import Testing
@testable import Core

@Suite("Model presets")
struct ModelPresetTests {
    static let opusHigh = ModelPreset(
        name: "Opus 5 High", model: "opus", effort: "high", backend: .claudeCode,
        outputStyle: "Explanatory", permissionMode: .bypassPermissions
    )
    static let solLow = ModelPreset(
        name: "Sol Low", model: "gpt-5.6-sol", effort: "low", backend: .codex,
        permissionMode: .autoReview
    )

    @Test("Applying writes every field the preset names at once")
    func applyingWritesEveryField() {
        let before = ComposerControls(
            model: "gpt-5.5", effort: "xhigh", agentKind: .codex,
            permissionMode: .autoReview, outputStyle: "Learning"
        )
        let after = before.applying(Self.opusHigh)
        #expect(after.agentKind == .claudeCode)
        #expect(after.model == "opus")
        #expect(after.effort == "high")
        #expect(after.outputStyle == "Explanatory")
        #expect(after.permissionMode == .bypassPermissions)
        #expect(after.matches(Self.opusHigh))
    }

    @Test("Applying leaves fast mode, the worktree and the context window alone")
    func applyingLeavesTheRestAlone() {
        let before = ComposerControls(
            isFastMode: true, codexContextWindow: 400_000, hasWorktree: false, codexFastMode: true
        )
        let after = before.applying(Self.solLow)
        #expect(after.isFastMode)
        #expect(after.codexFastMode == true)
        #expect(!after.hasWorktree)
        #expect(after.codexContextWindow == 400_000)
        #expect(after.permissionMode == .autoReview)
    }

    @Test("Applying settles the effort on a level the model takes")
    func applyingSettlesTheEffort() {
        let preset = ModelPreset(
            name: "GPT Ultra", model: "gpt-5.5", effort: "ultra", backend: .codex, permissionMode: .auto
        )
        let models: [AgentKind: [AgentModel]] = [
            .codex: [
                AgentModel(id: "gpt-5.5", displayName: "GPT-5.5", supportedEfforts: [
                    AgentModelEffort(id: "low", label: "Low"), AgentModelEffort(id: "medium", label: "Medium"),
                ], defaultEffort: "medium"),
            ],
        ]
        #expect(ComposerControls().applying(preset, models: models).effort == "medium")
        #expect(ComposerControls().applying(preset).effort == "ultra")
    }

    @Test("A preset cannot store a permission mode its backend lacks")
    func modeFollowsTheBackend() {
        let preset = ModelPreset(
            name: "Plan on Codex", model: "gpt-5.5", effort: "low", backend: .codex, permissionMode: .plan
        )
        #expect(preset.permissionMode == .auto)
    }

    @Test("Saving the composer captures every field a preset holds")
    func savingTheComposer() {
        let controls = ComposerControls(
            model: "sonnet", effort: "medium", permissionMode: .acceptEdits, outputStyle: "Learning"
        )
        let preset = ModelPreset(name: "Sonnet", controls: controls)
        #expect(preset.model == "sonnet")
        #expect(preset.effort == "medium")
        #expect(preset.backend == .claudeCode)
        #expect(preset.outputStyle == "Learning")
        #expect(preset.permissionMode == .acceptEdits)
        #expect(controls.matches(preset))
    }

    @Test("Any differing field makes the settings a one-off")
    func anyDifferenceIsAOneOff() {
        let controls = ComposerControls().applying(Self.opusHigh)
        var effort = controls
        effort.effort = "medium"
        var style = controls
        style.outputStyle = OutputStyle.defaultName
        var mode = controls
        mode.permissionMode = .acceptEdits
        var backend = controls
        backend.agentKind = .codex
        #expect(controls.matches(Self.opusHigh))
        #expect(!effort.matches(Self.opusHigh))
        #expect(!style.matches(Self.opusHigh))
        #expect(!mode.matches(Self.opusHigh))
        #expect(!backend.matches(Self.opusHigh))
    }

    @Test("A preset applied in a New Workspace draft survives the draft being kept")
    func survivesTheDraft() {
        let applied = ComposerControls(isFastMode: true).applying(Self.opusHigh)
        let kept = WorkspaceDraftControls(applied, usesCLIChat: false).applied(to: ComposerControls())
        #expect(kept.matches(Self.opusHigh))
        #expect(kept.isFastMode)
    }

    @Test("Codex has no output styles, so a style cannot make it a one-off there")
    func codexIgnoresTheOutputStyle() {
        var controls = ComposerControls().applying(Self.solLow)
        controls.outputStyle = "Learning"
        #expect(controls.matches(Self.solLow))
    }

    @Test("A preset the model cannot honour still counts as applied")
    func matchesTheSettledEffort() {
        let preset = ModelPreset(
            name: "GPT Ultra", model: "gpt-5.5", effort: "ultra", backend: .codex, permissionMode: .auto
        )
        let models: [AgentKind: [AgentModel]] = [
            .codex: [
                AgentModel(id: "gpt-5.5", displayName: "GPT-5.5", supportedEfforts: [
                    AgentModelEffort(id: "low", label: "Low"), AgentModelEffort(id: "medium", label: "Medium"),
                ], defaultEffort: "medium"),
            ],
        ]
        let applied = ComposerControls().applying(preset, models: models)
        #expect(applied.effort == "medium")
        #expect(applied.matches(preset, models: models))
        #expect(!applied.matches(preset))
    }

    @Test("A preset for an agent without output styles leaves the style alone")
    func codexPresetKeepsTheStyle() {
        let before = ComposerControls(outputStyle: "Explanatory")
        #expect(before.applying(Self.solLow).outputStyle == "Explanatory")
        #expect(!AgentKind.codex.offersOutputStyle)
        #expect(AgentKind.claudeCode.offersOutputStyle)
    }

    @Test("A blank name is no name", arguments: ["", "   ", "\n"])
    func blankNames(raw: String) {
        #expect(ModelPreset.cleanName(raw) == nil)
    }

    @Test("A name loses the space around it")
    func trimmedName() {
        #expect(ModelPreset.cleanName("  Deep  ") == "Deep")
    }
}
