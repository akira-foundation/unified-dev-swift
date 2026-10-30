import Foundation
import Testing
@testable import Core

@Suite("Agent settings in a preview scenario")
struct PreviewScenarioAgentSettingsTests {
    private let json = #"""
        {"projects":[{"name":"a"}],"agentSettings":{
          "github":"demo-user",
          "agents":[
            {"agent":"claudeCode","state":"connected","version":"2.1.0","details":[
              {"label":"Provider","value":"Anthropic"},
              {"label":"Login method","value":"Max account"},
              {"label":"Organization","value":"Demo Studio"},
              {"label":"Email","value":"demo@unifieddev.invalid"}]},
            {"agent":"codex","state":"installed","version":"0.50.0"}]}}
        """#

    @Test("a scenario without agent settings leaves the real agents to be probed")
    func noAgentSettings() throws {
        let scenario = try PreviewScenario.read(Data(#"{"projects":[{"name":"a"}]}"#.utf8))
        #expect(scenario.agentSettings == nil)
    }

    @Test("agent settings keep each agent's state, version, details and the GitHub account")
    func readsAgentSettings() throws {
        let settings = try #require(try PreviewScenario.read(Data(json.utf8)).agentSettings)
        #expect(settings.github == "demo-user")
        #expect(settings.agents == [
            PreviewScenario.AgentSettings.Agent(
                agent: .claudeCode,
                state: .connected,
                version: "2.1.0",
                details: [
                    .init(label: "Provider", value: "Anthropic"),
                    .init(label: "Login method", value: "Max account"),
                    .init(label: "Organization", value: "Demo Studio"),
                    .init(label: "Email", value: "demo@unifieddev.invalid"),
                ]
            ),
            PreviewScenario.AgentSettings.Agent(agent: .codex, state: .installed, version: "0.50.0"),
        ])
    }

    @Test("every agent gets a status, and one the scenario does not name is not installed")
    func statusesCoverEveryAgent() throws {
        let settings = try #require(try PreviewScenario.read(Data(json.utf8)).agentSettings)
        let statuses = settings.statuses
        #expect(statuses.map(\.kind) == AgentKind.allCases)

        let claude = try #require(statuses.first { $0.kind == .claudeCode })
        #expect(claude.connection == .connected)
        #expect(claude.version == "2.1.0")
        #expect(claude.details.map(\.value) == ["Anthropic", "Max account", "Demo Studio", "demo@unifieddev.invalid"])
        #expect(claude.executablePath == nil)

        #expect(statuses.first { $0.kind == .codex }?.connection == .installed)
        for status in statuses where status.kind != .claudeCode && status.kind != .codex {
            #expect(status == AgentStatus(kind: status.kind, connection: .notInstalled))
        }
    }

    @Test("the preview reads back exactly what the launch stored, and nothing when nothing was stored")
    func seededRoundTrip() throws {
        let defaults = TestDefaults.make("preview-agent-settings-\(UUID().uuidString)").defaults

        #expect(PreviewScenario.AgentSettings.seeded(in: defaults) == nil)

        let settings = try #require(try PreviewScenario.read(Data(json.utf8)).agentSettings)
        defaults.set(settings.stored(), forKey: PreviewScenario.agentSettingsKey)
        #expect(PreviewScenario.AgentSettings.seeded(in: defaults) == settings)

        defaults.set(Data("not json".utf8), forKey: PreviewScenario.agentSettingsKey)
        #expect(PreviewScenario.AgentSettings.seeded(in: defaults) == nil)
    }

    @Test("an adopted GitHub account is the one shown, and resolving asks nothing further")
    func adoptedGitHubAccount() async {
        GitHubIdentity.adopt("demo-user")
        await GitHubIdentity.resolve()
        #expect(GitHubIdentity.cachedUsername == "demo-user")
        GitHubIdentity.adopt(nil)
        #expect(GitHubIdentity.cachedUsername == nil)
    }

    @Test("an agent state the scenario does not know is unreadable")
    func unknownState() {
        let json = #"{"projects":[{"name":"a"}],"agentSettings":{"agents":[{"agent":"codex","state":"asleep"}]}}"#
        #expect(throws: PreviewScenarioError.self) { try PreviewScenario.read(Data(json.utf8)) }
    }

    @Test("agent settings that could not describe a machine are refused, and say why", arguments: [
        (#"{"agents":[{"agent":"codex","state":"installed"},{"agent":"codex","state":"connected"}]}"#, "named twice"),
        (#"{"agents":[{"agent":"grok","state":"notInstalled","version":"1.0"}]}"#, "not installed"),
        (#"{"agents":[{"agent":"grok","state":"notInstalled","details":[{"label":"Email","value":"x"}]}]}"#, "not installed"),
        (#"{"agents":[{"agent":"codex","state":"connected","details":[{"label":" ","value":"x"}]}]}"#, "has no label"),
        (#"{"agents":[{"agent":"codex","state":"connected","details":[{"label":"Plan","value":"x"},{"label":"Plan","value":"y"}]}]}"#, "\"Plan\" of agent codex is named twice"),
        (#"{"github":"  "}"#, "GitHub account in agent settings is blank"),
    ])
    func refuses(settings: String, reason: String) {
        let json = #"{"projects":[{"name":"a"}],"agentSettings":"# + settings + "}"
        do {
            _ = try PreviewScenario.read(Data(json.utf8))
            Issue.record("\(settings) was accepted")
        } catch PreviewScenarioError.invalid(let problems) {
            #expect(problems.count == 1)
            #expect(problems.first?.contains(reason) == true)
        } catch {
            Issue.record("\(settings) failed to read rather than being judged: \(error)")
        }
    }
}
