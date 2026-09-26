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

    @Test("Writes fast mode to the switch the backend reads, and leaves the other one alone")
    func writing() {
        let claudeOn = ComposerControls().settingFastMode(true)
        #expect(claudeOn.isFastMode)
        #expect(claudeOn.codexFastMode == nil)

        let claudeOff = ComposerControls(isFastMode: true, codexFastMode: true).settingFastMode(false)
        #expect(!claudeOff.isFastMode)
        #expect(claudeOff.codexFastMode == true)

        let codexOn = ComposerControls(agentKind: .codex, isFastMode: false).settingFastMode(true)
        #expect(codexOn.codexFastMode == true)
        #expect(!codexOn.isFastMode)

        let codexOff = ComposerControls(agentKind: .codex, isFastMode: true).settingFastMode(false)
        #expect(codexOff.codexFastMode == false)
        #expect(codexOff.isFastMode)
    }

    @Test("Switching Codex on and off again is what the toggle reads back as the bolt")
    func codexRoundTrip() {
        let speed = CodexSpeed(config: .object([:]), model: Self.fastModel)
        let untouched = ComposerControls(agentKind: .codex)
        #expect(!untouched.isFast(codexSpeed: speed))

        let switchedOn = untouched.settingFastMode(true)
        #expect(switchedOn.isFast(codexSpeed: speed))

        let switchedOff = switchedOn.settingFastMode(false)
        #expect(!switchedOff.isFast(codexSpeed: speed))
    }

    @Test("While Codex is being asked, the state says so rather than claiming off")
    func stateWhileLoading() {
        let priority = CodexSpeed(config: .object(["service_tier": .string("priority")]), model: Self.fastModel)
        let codex = ComposerControls(agentKind: .codex)

        #expect(codex.fastModeState(availability: .loading, codexSpeed: nil) == "Checking")
        #expect(codex.fastModeState(availability: .available, codexSpeed: priority) == "On")
        #expect(codex.settingFastMode(false).fastModeState(availability: .available, codexSpeed: priority) == "Off")
        #expect(ComposerControls(isFastMode: true).fastModeState(availability: .available, codexSpeed: nil) == "On")
        #expect(ComposerControls().fastModeState(availability: .available, codexSpeed: nil) == "Off")
    }

    @Test("The help says what fast mode costs on the agent in use, and how far a change reaches")
    func help() {
        #expect(
            ComposerControls(agentKind: .codex).fastModeHelp(availability: .available)
                == "Faster replies use more of your Codex allowance. Changes apply to this conversation."
        )
        #expect(
            ComposerControls().fastModeHelp(availability: .available)
                == "Disable thinking for faster replies. Changes apply to this conversation."
        )
        #expect(
            ComposerControls(agentKind: .codex).fastModeHelp(availability: .loading)
                == "Checking whether this model has fast mode."
        )
    }

    @Test("The help never repeats the name the control already carries")
    func helpDoesNotRepeatTheLabel() {
        let texts = [FastModeAvailability.available, .loading].flatMap { availability in
            [ComposerControls(), ComposerControls(agentKind: .codex)].map {
                $0.fastModeHelp(availability: availability)
            }
        }
        #expect(texts.allSatisfy { !$0.lowercased().contains("fast mode:") })
    }
}
