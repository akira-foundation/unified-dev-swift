import Testing
@testable import Core

@Suite("Composer effort", .tags(.persistence), .scratchDirectory)
struct ComposerEffortTests {
    private let supported = [
        AgentModelEffort(id: "low", label: "Low"),
        AgentModelEffort(id: "xhigh", label: "Extra high"),
        AgentModelEffort(id: "ultra", label: "Ultra thinking"),
    ]

    @Test("a chat with no effort of its own is never named by the first one on the list")
    func anUnsetEffortIsNeverNamedByTheFirstOfTheList() {
        let offered = ComposerEffort.choices(supported, offeringUnset: true)

        #expect(ComposerEffort.label(for: "", among: offered) == "Agent default")
        #expect(ComposerEffort.label(for: "", among: supported) == "Agent default")
        #expect(ComposerEffort.label(for: "   ", among: offered) == "Agent default")
        #expect(ComposerEffort.label(for: "\n", among: offered) == "Agent default")
    }

    @Test("the composer offers the unset row first, and nothing else offers it")
    func onlyTheComposerOffersTheUnsetRow() {
        let offered = ComposerEffort.choices(supported, offeringUnset: true)
        let plain = ComposerEffort.choices(supported, offeringUnset: false)

        #expect(offered.first?.id == ComposerEffort.unsetID)
        #expect(offered.first?.label == "Agent default")
        #expect(offered.dropFirst().map(\.id) == supported.map(\.id))
        #expect(plain == supported)
        #expect(!plain.contains { ComposerEffort.isUnset($0.id) })
    }

    @Test("a catalogue that has not answered yet offers the unset row and nothing else")
    func anEmptyCatalogueStillOffersTheUnsetRow() {
        #expect(ComposerEffort.choices([], offeringUnset: true).map(\.id) == [ComposerEffort.unsetID])
        #expect(ComposerEffort.choices([], offeringUnset: false).isEmpty)
    }

    @Test("a list that already carries the unset row does not gain a second one")
    func theUnsetRowIsOfferedOnce() {
        let already = [AgentModelEffort(id: "", label: "Whatever")] + supported

        #expect(ComposerEffort.choices(already, offeringUnset: true) == already)
    }

    @Test("an effort the agent named is shown under the agent's own label, not a title-cased id")
    func aKnownEffortKeepsTheAgentsLabel() {
        #expect(ComposerEffort.label(for: "xhigh", among: supported) == "Extra high")
        #expect(ComposerEffort.label(for: "ultra", among: supported) == "Ultra thinking")
        #expect(ModelLabel.readable("xhigh") == "Xhigh")
    }

    @Test("an effort the agent does not list is made readable rather than shown raw")
    func anUnknownEffortIsMadeReadable() {
        #expect(ComposerEffort.label(for: "extra_high", among: supported) == "Extra High")
    }

    @Test("an effort nobody chose survives a model that has a default of its own")
    func theUnsetEffortIsNotCoercedToAModelDefault() {
        let models: [AgentKind: [AgentModel]] = [
            .codex: [AgentModel(id: "gpt", displayName: "GPT", defaultEffort: "medium")],
        ]

        #expect(DefaultBackend.effort("", on: .codex, model: "gpt", models: models) == "")
        #expect(DefaultBackend.effort("   ", on: .codex, model: "gpt", models: models) == "")
        #expect(DefaultBackend.effort("\n", on: .codex, model: "gpt", models: models) == "")
        #expect(DefaultBackend.effort("low", on: .codex, model: "gpt", models: models) == "medium")
    }

    @Test("an agent whose models announce no efforts keeps the level the chat already had")
    func anAgentThatAnnouncesNoEffortsKeepsTheChosenLevel() {
        let models: [AgentKind: [AgentModel]] = [
            .claudeCode: ClaudeModelCatalog.builtIn,
            .codex: [AgentModel(id: "gpt", displayName: "GPT", defaultEffort: "medium")],
        ]

        #expect(!AgentKind.claudeCode.announcesModelEfforts)
        #expect(DefaultBackend.effort("high", on: .claudeCode, model: "sonnet", models: models) == "high")
        #expect(DefaultBackend.effort("max", on: .claudeCode, model: "opus", models: models) == "max")
        #expect(DefaultBackend.effort("high", on: .codex, model: "gpt", models: models) == "medium")
    }

    @Test("a model announced with no effort information is given none, not the one the chat carried")
    func aModelThatAnnouncesNoEffortsIsGivenNone() {
        let models: [AgentKind: [AgentModel]] = [
            .grok: [AgentModel(id: "grok-4.6", displayName: "Grok 4.6")],
            .codex: [AgentModel(id: "bare", displayName: "Bare")],
        ]

        #expect(AgentKind.grok.announcesModelEfforts)
        #expect(AgentKind.codex.announcesModelEfforts)
        #expect(DefaultBackend.effort("max", on: .grok, model: "grok-4.6", models: models) == "")
        #expect(DefaultBackend.effort("max", on: .codex, model: "bare", models: models) == "")
    }

    @Test("a model the catalogue has never heard of keeps the level the chat had")
    func anUnknownModelKeepsTheChosenLevel() {
        let models: [AgentKind: [AgentModel]] = [
            .grok: [AgentModel(id: "grok-4.6", displayName: "Grok 4.6", defaultEffort: "low")],
        ]

        #expect(DefaultBackend.effort("high", on: .grok, model: "grok-9", models: models) == "high")
    }

    @Test("a default preset that chose the agent default is not outranked by a settings file")
    func aPresetThatChoseTheAgentDefaultOutranksASettingsFile() async throws {
        let store = try makeTestStore("composer-effort-agent-default-preset")
        await AppDefaults(model: "gpt", effort: "high", backend: .codex).save(to: store)
        let agentDefault = ModelPreset(
            name: "Agent default", model: "gpt", effort: "", backend: .codex, permissionMode: .autoReview
        )
        var list = ModelPresetList(presets: [agentDefault])
        list.setDefault(agentDefault.id)
        try await list.save(to: store)

        let defaults = await AppDefaults.loadForNewSessions(from: store)
        var repo = RepoSettings()
        repo.homeDefaultEffort = "medium"

        #expect(defaults.storedEffort == "")
        #expect(ComposerDefaults.effort(repo: repo, app: defaults) == "")
        #expect(ComposerDefaults.resolve(repo: repo, app: defaults).effort == "")
    }

    @Test("a project that names a level outranks the preset, and a blank one does not")
    func aProjectLevelOutranksThePreset() {
        var app = AppDefaults()
        app.effort = "high"
        app.storedEffort = ""
        var repo = RepoSettings()
        repo.homeDefaultEffort = "medium"

        #expect(ComposerDefaults.effort(repo: repo, app: app) == "")
        repo.defaultEffort = "   "
        #expect(ComposerDefaults.effort(repo: repo, app: app) == "")
        repo.defaultEffort = "\n"
        #expect(ComposerDefaults.effort(repo: repo, app: app) == "")
        repo.defaultEffort = "max"
        #expect(ComposerDefaults.effort(repo: repo, app: app) == "max")
    }

    @Test("with nothing chosen anywhere the settings file still decides")
    func withNothingChosenTheSettingsFileDecides() {
        var app = AppDefaults()
        app.effort = "high"
        app.storedEffort = nil
        var repo = RepoSettings()
        repo.homeDefaultEffort = "medium"

        #expect(ComposerDefaults.effort(repo: repo, app: app) == "medium")
        repo.homeDefaultEffort = nil
        #expect(ComposerDefaults.effort(repo: repo, app: app) == "high")
    }

    @Test("a preset made from an unset effort matches the controls it was made from")
    func aPresetOfTheUnsetEffortRoundTrips() {
        let models: [AgentKind: [AgentModel]] = [
            .codex: [AgentModel(id: "gpt", displayName: "GPT", defaultEffort: "medium")],
        ]
        let controls = ComposerControls(model: "gpt", effort: "", agentKind: .codex)
        let preset = ModelPreset(name: "Agent default", controls: controls)

        #expect(preset.effort == "")
        #expect(controls.matches(preset, models: models))
        #expect(controls.applying(preset, models: models).effort == "")
    }

    @Test("the summary names the unset effort rather than leaving the line half written")
    func theSummaryNamesTheUnsetEffort() {
        let controls = ComposerControls(model: "gpt", effort: "", agentKind: .codex)
        let summary = ComposerPresetSummary(
            controls: controls,
            presets: ModelPresetList(presets: []),
            modelLabel: "GPT",
            effortLabel: ComposerEffort.label(for: controls.effort, among: supported)
        )

        #expect(summary.title == "GPT \u{00B7} Agent default")
        #expect(summary.suggestedName == "GPT Agent default")
    }

    @Test("the runner omits exactly the efforts the composer calls unset")
    func theRunnerOmitsExactlyWhatIsUnset() {
        for effort in ["", "   ", "\n", "high", "max"] {
            var session = Session(workspaceID: WorkspaceID("w1"), model: "opus")
            session.effort = effort
            let omitted = !AgentRunner.argv(session: session, resume: nil).contains("--effort")

            #expect(omitted == ComposerEffort.isUnset(effort), "effort \(effort.debugDescription)")
        }
    }
}
