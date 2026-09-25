import Testing
@testable import Core

@Suite("Fast mode in the composer")
struct ComposerFastModeTests {
    private static let fastModel = CodexModel(id: "fast-model", displayName: "Fast", fastServiceTier: "priority")
    private static let plainModel = CodexModel(id: "plain-model", displayName: "Plain")

    @Test("Offered on Claude Code always, and on Codex once the server says the model has it")
    func availability() {
        let supported = CodexSpeed(config: .object([:]), model: Self.fastModel)
        let unsupported = CodexSpeed(config: .object([:]), model: Self.plainModel)
        let claude = ComposerControls()
        let codex = ComposerControls(agentKind: .codex)

        #expect(claude.fastModeAvailability(codexSpeed: nil, codexSpeedFailed: false) == .available)
        #expect(codex.fastModeAvailability(codexSpeed: nil, codexSpeedFailed: false) == .loading)
        #expect(codex.fastModeAvailability(codexSpeed: nil, codexSpeedFailed: true) == .unavailable)
        #expect(codex.fastModeAvailability(codexSpeed: supported, codexSpeedFailed: false) == .available)
        #expect(codex.fastModeAvailability(codexSpeed: unsupported, codexSpeedFailed: false) == .unavailable)
    }

    @Test("Agents that send nothing for fast mode never offer it", arguments: [AgentKind.grok, .cursor, .openCode])
    func silentAgents(kind: AgentKind) {
        let controls = ComposerControls(agentKind: kind)
        #expect(controls.fastModeAvailability(codexSpeed: nil, codexSpeedFailed: false) == .unavailable)
    }

    @Test("Reads fast mode from the switch each backend keeps it in")
    func reading() {
        let priority = CodexSpeed(config: .object(["service_tier": .string("priority")]), model: Self.fastModel)

        #expect(ComposerControls(isFastMode: true).isFast(codexSpeed: nil))
        #expect(!ComposerControls(agentKind: .codex, isFastMode: true).isFast(codexSpeed: nil))
        #expect(ComposerControls(agentKind: .codex).isFast(codexSpeed: priority))
        #expect(!ComposerControls(agentKind: .codex, codexFastMode: false).isFast(codexSpeed: priority))
    }

    @Test("Writes fast mode to the switch the backend reads")
    func writing() {
        let claude = ComposerControls().settingFastMode(true)
        #expect(claude.isFastMode)
        #expect(claude.codexFastMode == nil)

        let codex = ComposerControls(agentKind: .codex).settingFastMode(false)
        #expect(!codex.isFastMode)
        #expect(codex.codexFastMode == false)
    }

    @Test("The help says what fast mode costs on the agent in use")
    func help() {
        #expect(
            ComposerControls(agentKind: .codex).fastModeHelp(availability: .available)
                == "Fast mode: faster replies use more of your Codex allowance"
        )
        #expect(ComposerControls().fastModeHelp(availability: .available) == "Fast mode: disable thinking for faster replies")
        #expect(
            ComposerControls(agentKind: .codex).fastModeHelp(availability: .loading)
                == "Checking whether this model has fast mode"
        )
    }
}
