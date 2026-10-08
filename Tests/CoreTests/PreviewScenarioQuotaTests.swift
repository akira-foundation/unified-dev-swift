import Foundation
import Testing
@testable import Core

@Suite("Usage readings in a preview scenario")
struct PreviewScenarioQuotaTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    @Test("a scenario without readings reads as before")
    func noReadings() throws {
        let scenario = try PreviewScenario.read(Data(#"{"projects":[{"name":"a"}]}"#.utf8))
        #expect(scenario.quotas.isEmpty)
    }

    @Test("readings keep their provider, window, amount and reset")
    func readsReadings() throws {
        let json = #"""
            {"projects":[{"name":"a"}],"quotas":[
              {"provider":"codex","window":"primary","hours":168,"used":1,"resetsInMinutes":2340},
              {"provider":"claudeCode","window":"seven_day_model_fable","label":"Week (Fable)","used":0.71}]}
            """#
        let scenario = try PreviewScenario.read(Data(json.utf8))
        #expect(scenario.quotas == [
            PreviewScenario.Quota(provider: .codex, window: "primary", hours: 168, used: 1, resetsInMinutes: 2340),
            PreviewScenario.Quota(provider: .claudeCode, window: "seven_day_model_fable", label: "Week (Fable)", used: 0.71),
        ])
    }

    @Test("a reading becomes the quota an agent would have reported, dated from the seeding")
    func buildsTheQuota() {
        let codex = PreviewScenario.Quota(provider: .codex, window: "primary", hours: 168, used: 1, resetsInMinutes: 2340)
            .quota(at: now)
        #expect(codex.window == QuotaWindow(key: "primary", label: "Week", duration: 604_800))
        #expect(codex.fraction == 1)
        #expect(codex.resetsAt == now.addingTimeInterval(140_400))
        #expect(codex.observedAt == now)
        #expect(UsageCatalogue.title(for: codex) == "Weekly")

        let session = PreviewScenario.Quota(provider: .claudeCode, window: "five_hour").quota(at: now)
        #expect(session.window.duration == 18_000)
        #expect(session.measure == .unknown)
        #expect(session.resetsAt == nil)
    }

    @Test("a reading carries how long before the launch it was taken")
    func readingCarriesItsAge() throws {
        let json = #"""
            {"projects":[{"name":"a"}],"quotas":[
              {"provider":"claudeCode","window":"seven_day","used":0.09,"readMinutesAgo":45}]}
            """#
        let scenario = try PreviewScenario.read(Data(json.utf8))
        #expect(scenario.quotas.first?.readMinutesAgo == 45)
        #expect(scenario.quotas.first?.quota(at: now).observedAt == now.addingTimeInterval(-2700))
    }

    @Test("an agent the scenario answers nothing for is named, and holds the seeded readings")
    func silentAgents() throws {
        let json = #"{"projects":[{"name":"a"}],"silentAgents":["claudeCode"]}"#
        let scenario = try PreviewScenario.read(Data(json.utf8))
        #expect(scenario.silentAgents == [.claudeCode])
        #expect(scenario.holdsSeededQuotas)
    }

    @Test("a stored silence is read back as the agents that report usage, and nothing else")
    func silenceReadBack() {
        #expect(PreviewScenario.agents(storedAs: ["claudeCode", "codex"]) == [.claudeCode, .codex])
        #expect(PreviewScenario.agents(storedAs: ["grok"]).isEmpty)
        #expect(PreviewScenario.agents(storedAs: ["nobody"]).isEmpty)
        #expect(PreviewScenario.agents(storedAs: []).isEmpty)
    }

    @Test("an agent the scenario answers without limits for is named, and holds the seeded readings")
    func agentsWithoutLimits() throws {
        let json = #"{"projects":[{"name":"a"}],"agentsWithoutLimits":["claudeCode"]}"#
        let scenario = try PreviewScenario.read(Data(json.utf8))
        #expect(scenario.agentsWithoutLimits == [.claudeCode])
        #expect(scenario.holdsSeededQuotas)
    }

    @Test("a scenario that says nothing about usage lets the real agents be asked")
    func saysNothingAboutUsage() throws {
        let bare = try PreviewScenario.read(Data(#"{"projects":[{"name":"a"}]}"#.utf8))
        #expect(!bare.holdsSeededQuotas)

        let json = #"{"projects":[{"name":"a"}],"quotas":[{"provider":"codex","window":"primary","used":0.2}]}"#
        let seeded = try PreviewScenario.read(Data(json.utf8))
        #expect(seeded.holdsSeededQuotas)
    }

    @Test("an agent the scenario does not know is unreadable")
    func unknownAgent() {
        let json = #"{"projects":[{"name":"a"}],"quotas":[{"provider":"nobody","window":"x"}]}"#
        #expect(throws: PreviewScenarioError.self) { try PreviewScenario.read(Data(json.utf8)) }
    }

    @Test("a reading that could not have been reported is refused, and says why", arguments: [
        (#"{"projects":[{"name":"a"}],"quotas":[{"provider":"grok","window":"x"}]}"#, "reports no usage"),
        (#"{"projects":[{"name":"a"}],"quotas":[{"provider":"codex","window":" "}]}"#, "names no window"),
        (#"{"projects":[{"name":"a"}],"quotas":[{"provider":"codex","window":"primary","used":-0.1}]}"#, "negative amount"),
        (#"{"projects":[{"name":"a"}],"quotas":[{"provider":"codex","window":"primary","used":71}]}"#, "more than the whole limit"),
        (#"{"projects":[{"name":"a"}],"quotas":[{"provider":"codex","window":"primary","hours":0}]}"#, "lasts no time"),
        (#"{"projects":[{"name":"a"}],"quotas":[{"provider":"codex","window":"primary","resetsInMinutes":0}]}"#, "resets in the past"),
        (#"{"projects":[{"name":"a"}],"quotas":[{"provider":"codex","window":"primary"},{"provider":"codex","window":"primary"}]}"#, "named twice"),
        (#"{"projects":[{"name":"a"}],"quotas":[{"provider":"codex","window":"primary","readMinutesAgo":-1}]}"#, "read in the future"),
        (#"{"projects":[{"name":"a"}],"silentAgents":["grok"]}"#, "reports no usage"),
        (#"{"projects":[{"name":"a"}],"agentsWithoutLimits":["grok"]}"#, "without limits reports no usage"),
    ])
    func refuses(json: String, reason: String) {
        do {
            _ = try PreviewScenario.read(Data(json.utf8))
            Issue.record("\(json) was accepted")
        } catch PreviewScenarioError.invalid(let problems) {
            #expect(problems.count == 1)
            #expect(problems.first?.contains(reason) == true)
        } catch {
            Issue.record("\(json) failed to read rather than being judged: \(error)")
        }
    }
}
