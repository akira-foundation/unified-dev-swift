import Testing
@testable import Core

@Suite("Composer effort")
struct ComposerEffortTests {
    private let supported = [
        ComposerEffortChoice(id: "low", label: "Low"),
        ComposerEffortChoice(id: "medium", label: "Medium"),
        ComposerEffortChoice(id: "high", label: "High"),
    ]

    @Test("a chat with no effort of its own is never named by the first one on the list")
    func anUnsetEffortIsNeverNamedByTheFirstOfTheList() {
        let offered = ComposerEffort.choices(supported, offeringUnset: true)

        #expect(ComposerEffort.label(for: "", among: offered) == "Agent default")
        #expect(ComposerEffort.label(for: "", among: offered) != supported[0].label)
        #expect(ComposerEffort.label(for: "", among: supported) == "Agent default")
        #expect(ComposerEffort.label(for: "   ", among: offered) == "Agent default")
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

    @Test("a list that already carries the unset row does not gain a second one")
    func theUnsetRowIsOfferedOnce() {
        let already = [ComposerEffortChoice(id: "", label: "Whatever")] + supported

        #expect(ComposerEffort.choices(already, offeringUnset: true) == already)
    }

    @Test("an effort the agent knows is named by its own label")
    func aKnownEffortKeepsItsLabel() {
        #expect(ComposerEffort.label(for: "high", among: supported) == "High")
    }

    @Test("an effort the agent does not list is made readable rather than shown raw")
    func anUnknownEffortIsMadeReadable() {
        let label = ComposerEffort.label(for: "extra_high", among: supported)

        #expect(label == "Extra High")
        #expect(label != ComposerEffort.unsetLabel)
    }

    @Test("an effort nobody chose survives a model that has a default of its own")
    func theUnsetEffortIsNotCoercedToAModelDefault() {
        let models: [AgentKind: [AgentModel]] = [
            .codex: [AgentModel(id: "gpt", displayName: "GPT", defaultEffort: "medium")],
        ]

        #expect(DefaultBackend.effort("", on: .codex, model: "gpt", models: models) == "")
        #expect(DefaultBackend.effort("   ", on: .codex, model: "gpt", models: models) == "")
        #expect(DefaultBackend.effort("low", on: .codex, model: "gpt", models: models) == "medium")
    }

    @Test("a model that declares no efforts keeps the one the chat already had")
    func aModelWithNoEffortsOfItsOwnKeepsTheChosenOne() {
        let models: [AgentKind: [AgentModel]] = [
            .claudeCode: ClaudeModelCatalog.builtIn,
            .codex: [AgentModel(id: "gpt", displayName: "GPT", defaultEffort: "medium")],
        ]

        #expect(ClaudeModelCatalog.builtIn.allSatisfy { !$0.declaresEfforts })
        #expect(DefaultBackend.effort("high", on: .claudeCode, model: "sonnet", models: models) == "high")
        #expect(DefaultBackend.effort("high", on: .claudeCode, model: "opus", models: models) == "high")
        #expect(DefaultBackend.effort("high", on: .codex, model: "gpt", models: models) == "medium")
    }

    @Test("a default preset that chose the agent default is not outranked by a settings file")
    func aPresetThatChoseTheAgentDefaultOutranksASettingsFile() {
        var repo = RepoSettings()
        repo.homeDefaultEffort = "medium"
        var app = AppDefaults()
        app.model = "gpt"
        app.backend = .codex
        app.effort = "high"

        app.storedEffort = nil
        #expect(ComposerDefaults.effort(repo: repo, app: app) == "medium")

        app.storedEffort = ""
        #expect(ComposerDefaults.effort(repo: repo, app: app) == "")

        app.storedEffort = "low"
        #expect(ComposerDefaults.effort(repo: repo, app: app) == "low")

        repo.defaultEffort = "max"
        #expect(ComposerDefaults.effort(repo: repo, app: app) == "max")
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

    @Test("the unset effort is the one the runner leaves out of its arguments")
    func theUnsetEffortIsTheOneTheRunnerOmits() {
        var session = Session(workspaceID: WorkspaceID("w1"), model: "opus")
        session.effort = ""
        let unset = AgentRunner.argv(session: session, resume: nil)

        session.effort = "high"
        let chosen = AgentRunner.argv(session: session, resume: nil)

        #expect(ComposerEffort.isUnset(""))
        #expect(!unset.contains("--effort"))
        #expect(chosen.contains("--effort"))
        #expect(ComposerEffort.label(for: "", among: []) == ComposerEffort.unsetLabel)
    }
}
