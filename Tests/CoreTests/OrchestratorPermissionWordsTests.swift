import Testing
@testable import Core

@Suite("What an orchestrator chat says about its permissions")
struct OrchestratorPermissionWordsTests {
    private func controls(_ kind: AgentKind, _ mode: PermissionMode) -> ComposerControls {
        var controls = ComposerControls(agentKind: kind)
        controls.permissionMode = mode
        return controls
    }

    @Test("Claude Code asking is named as the mode the runner really launches", arguments: [
        PermissionMode.bypassPermissions, .acceptEdits, .auto,
    ])
    func claudeNamesTheAskingMode(mode: PermissionMode) {
        let controls = controls(.claudeCode, mode)
        #expect(controls.permissionLabel(orchestrates: true) == "Default")
        #expect(controls.runningPermissionMode(orchestrates: true) == .auto)
    }

    @Test("Plan stays Plan, because the runner launches it as Plan")
    func planIsKept() {
        #expect(controls(.claudeCode, .plan).permissionLabel(orchestrates: true) == "Plan")
    }

    @Test("Codex and Grok name the mode their runner forces")
    func otherAgentsNameTheForcedMode() {
        #expect(controls(.codex, .bypassPermissions).permissionLabel(orchestrates: true) == "Read only")
        #expect(controls(.grok, .bypassPermissions).permissionLabel(orchestrates: true) == "Auto")
    }

    @Test("Outside an orchestrator the chosen mode is the mode")
    func ordinaryChatKeepsItsMode() {
        let controls = controls(.claudeCode, .bypassPermissions)
        #expect(controls.permissionLabel(orchestrates: false) == "Bypass permissions")
        #expect(controls.runningPermissionMode(orchestrates: false) == .bypassPermissions)
        #expect(controls.permissionModeChoices(orchestrates: false).map(\.mode)
            == [.auto, .acceptEdits, .bypassPermissions, .plan])
    }

    @Test("The picker offers only what an orchestrator can run")
    func pickerOffersWhatCanRun() {
        let claude = controls(.claudeCode, .bypassPermissions).permissionModeChoices(orchestrates: true)
        #expect(claude.map(\.mode) == [.auto, .plan])
        #expect(claude.map(\.label) == ["Default", "Plan"])
        #expect(claude[0].summary.contains("file edits and git changes are refused"))
        #expect(!claude[0].summary.contains("Bypass"))

        let codex = controls(.codex, .acceptEdits).permissionModeChoices(orchestrates: true)
        #expect(codex.map(\.mode) == [.auto])
        #expect(codex.map(\.label) == ["Read only"])
        #expect(codex[0].summary == PermissionMode.auto.summary(on: .codex))

        let grok = controls(.grok, .bypassPermissions).permissionModeChoices(orchestrates: true)
        #expect(grok.map(\.mode) == [.auto, .plan])
        #expect(grok.map(\.label) == ["Auto", "Plan"])
    }

    @Test("The settings button reads the running mode")
    func settingsButtonReadsTheRunningMode() {
        let summary = ComposerPresetSummary(
            controls: controls(.claudeCode, .bypassPermissions), presets: ModelPresetList(presets: []),
            modelLabel: "Opus", effortLabel: "Low", orchestrates: true
        )
        #expect(summary.accessibilityValue == "Opus, Low, Default")
    }

    @Test("A denial in an orchestrator advises no other mode", arguments: [1, 3])
    func denialAdvisesNoMode(count: Int) throws {
        let note = try #require(
            TurnEnding.denied(count).note(permissionMode: .bypassPermissions, agentKind: .claudeCode, orchestrates: true)
        )
        #expect(!note.contains("Pick another"))
        #expect(note.contains("would not change that"))
        #expect(!note.contains("Bypass permissions"))
        #expect(note.contains("orchestrator"))
        #expect(note.contains(count == 1 ? "1 tool call was" : "3 tool calls were"))
    }

    @Test("A denial elsewhere still names the mode and the way out")
    func denialElsewhereKeepsTheAdvice() throws {
        let note = try #require(TurnEnding.denied(1).note(permissionMode: .acceptEdits, agentKind: .claudeCode))
        #expect(note.contains("Pick another permission mode"))
        #expect(note.contains("Accept edits"))
    }
}
