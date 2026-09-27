import Testing
@testable import Core

@Suite("What a new session starts on", .tags(.persistence), .scratchDirectory)
struct NewSessionDefaultsTests {
    static let opusHigh = ModelPreset(
        name: "Opus 5 High", model: "opus", effort: "high", backend: .claudeCode,
        permissionMode: .bypassPermissions
    )
    static let solLow = ModelPreset(
        name: "Sol Low", model: "gpt-5.6-sol", effort: "low", backend: .codex, permissionMode: .autoReview
    )

    @Test("The default preset is what a new session starts on")
    func defaultPresetWins() async throws {
        let store = try makeTestStore("new-session-default-preset")
        await AppDefaults(model: "sonnet", effort: "low", permissionMode: .acceptEdits).save(to: store)
        var list = ModelPresetList(presets: [Self.solLow, Self.opusHigh])
        list.setDefault(Self.solLow.id)
        try await list.save(to: store)

        let defaults = await AppDefaults.loadForNewSessions(from: store)
        let resolved = ComposerDefaults.resolve(repo: RepoSettings(), app: defaults)
        #expect(resolved.model == "gpt-5.6-sol")
        #expect(resolved.backend == .codex)
        #expect(resolved.effort == "low")
        #expect(resolved.permissionMode == .autoReview)

        let controls = ComposerControls.resolved(repo: RepoSettings(), app: defaults)
        #expect(controls.matches(Self.solLow))
    }

    @Test("Settings keeps showing its own values under a default preset")
    func settingsKeepsItsValues() async throws {
        let store = try makeTestStore("new-session-settings-values")
        await AppDefaults(model: "sonnet", effort: "low").save(to: store)
        var list = ModelPresetList(presets: [Self.opusHigh])
        list.setDefault(Self.opusHigh.id)
        try await list.save(to: store)

        #expect(await AppDefaults.load(from: store).model == "sonnet")
    }

    @Test("With presets but no default, new sessions use Settings")
    func noDefault() async throws {
        let store = try makeTestStore("new-session-no-default")
        await AppDefaults(model: "sonnet", effort: "low").save(to: store)
        try await ModelPresetList(presets: [Self.opusHigh]).save(to: store)

        #expect(await AppDefaults.loadForNewSessions(from: store).model == "sonnet")
    }

    @Test("A repository's own model still outranks the default preset")
    func repositoryWins() async throws {
        let store = try makeTestStore("new-session-repository-wins")
        var list = ModelPresetList(presets: [Self.opusHigh])
        list.setDefault(Self.opusHigh.id)
        try await list.save(to: store)
        var repo = RepoSettings()
        repo.defaultModel = "sonnet"
        repo.defaultEffort = "medium"

        let defaults = await AppDefaults.loadForNewSessions(from: store)
        let resolved = ComposerDefaults.resolve(repo: repo, app: defaults)
        #expect(resolved.model == "sonnet")
        #expect(resolved.effort == "medium")
    }

    @Test("A default preset outranks starting in plan mode, and the session matches it")
    func presetOutranksPlanMode() async throws {
        let store = try makeTestStore("new-session-plan-mode")
        await AppDefaults(model: "sonnet", effort: "low", planMode: true).save(to: store)
        var list = ModelPresetList(presets: [Self.opusHigh])
        list.setDefault(Self.opusHigh.id)
        try await list.save(to: store)

        let defaults = await AppDefaults.loadForNewSessions(from: store)
        let controls = ComposerControls.resolved(repo: RepoSettings(), app: defaults)
        #expect(controls.permissionMode == .bypassPermissions)
        #expect(controls.matches(Self.opusHigh))
    }

    @Test("A preset that is itself Plan still starts the session in Plan")
    func planPresetStaysInPlan() async throws {
        let store = try makeTestStore("new-session-plan-preset")
        let planning = ModelPreset(
            name: "Opus Plan", model: "opus", effort: "high", backend: .claudeCode, permissionMode: .plan
        )
        var list = ModelPresetList(presets: [planning])
        list.setDefault(planning.id)
        try await list.save(to: store)

        let defaults = await AppDefaults.loadForNewSessions(from: store)
        #expect(defaults.planMode)
        #expect(ComposerControls.resolved(repo: RepoSettings(), app: defaults).permissionMode == .plan)
    }

    @Test("A preset for an agent without output styles leaves the Settings style alone")
    func codexPresetKeepsTheStyle() async throws {
        let store = try makeTestStore("new-session-output-style")
        await AppDefaults(model: "opus", effort: "high", outputStyle: "Explanatory").save(to: store)
        var list = ModelPresetList(presets: [Self.solLow])
        list.setDefault(Self.solLow.id)
        try await list.save(to: store)

        #expect(await AppDefaults.loadForNewSessions(from: store).outputStyle == "Explanatory")
    }

    @Test("Applying a preset marks the model and effort as chosen")
    func applyingMarksAChoice() {
        let applied = AppDefaults().applying(Self.solLow)
        #expect(applied.storedModel == "gpt-5.6-sol")
        #expect(applied.storedEffort == "low")
        #expect(applied.backend == .codex)
        #expect(applied.outputStyle == OutputStyle.defaultName)
        #expect(applied.permissionMode == .autoReview)
    }
}
