import Testing
import Foundation
@testable import Core

@Suite("The controls a new conversation opens with")
struct ComposerControlsResolvedTests {
    @Test("the output style chosen in Settings reaches a conversation nobody opened the composer for")
    func carriesTheOutputStyle() {
        var app = AppDefaults()
        app.outputStyle = "Concise"
        app.fastMode = true
        app.codexContextWindow = 1_000_000

        let controls = ComposerControls.resolved(repo: RepoSettings(), app: app)

        #expect(controls.outputStyle == "Concise")
        #expect(controls.isFastMode)
        #expect(controls.codexContextWindow == 1_000_000)
    }

    @Test("plan mode on Claude Code arrives as the plan permission mode")
    func carriesPlanModeOnClaude() {
        var app = AppDefaults()
        app.planMode = true

        let controls = ComposerControls.resolved(repo: RepoSettings(), app: app)

        #expect(controls.agentKind == .claudeCode)
        #expect(controls.permissionMode == .plan)
        #expect(controls.interactionMode == .build)
    }

    @Test("plan mode on Codex arrives as the plan interaction mode")
    func carriesPlanModeOnCodex() {
        var app = AppDefaults(model: "gpt-5.6-sol", effort: "high", backend: .codex)
        app.planMode = true

        let controls = ComposerControls.resolved(repo: RepoSettings(), app: app)

        #expect(controls.agentKind == .codex)
        #expect(controls.interactionMode == .plan)
        #expect(controls.permissionMode != .plan)
        #expect(controls.availablePermissionModes.contains(controls.permissionMode))
    }

    @Test("a repository default outranks the Settings screen")
    func repositorySettingsOutrankTheApp() {
        var repo = RepoSettings()
        repo.defaultModel = "sonnet"
        var app = AppDefaults()
        app.model = "opus"

        let controls = ComposerControls.resolved(repo: repo, app: app)

        #expect(controls.model == "sonnet")
    }

    @Test("every field it settles is the field ComposerDefaults settled")
    func agreesWithComposerDefaults() {
        var app = AppDefaults()
        app.planMode = true
        app.outputStyle = "Explanatory"
        let defaults = ComposerDefaults.resolve(repo: RepoSettings(), app: app)

        let controls = ComposerControls.resolved(repo: RepoSettings(), app: app)

        #expect(controls.model == defaults.model)
        #expect(controls.effort == defaults.effort)
        #expect(controls.agentKind == defaults.backend)
        #expect(controls.permissionMode == defaults.permissionMode)
        #expect(controls.interactionMode == defaults.interactionMode)
        #expect(controls.outputStyle == "Explanatory")
    }
}
