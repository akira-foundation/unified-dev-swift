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

    @Test("an agent the scenario does not know is unreadable")
    func unknownAgent() {
        let json = #"{"projects":[{"name":"a"}],"quotas":[{"provider":"nobody","window":"x"}]}"#
        #expect(throws: PreviewScenarioError.self) { try PreviewScenario.read(Data(json.utf8)) }
    }

    @Test("a reading that could not have been reported is refused", arguments: [
        #"{"projects":[{"name":"a"}],"quotas":[{"provider":"grok","window":"x"}]}"#,
        #"{"projects":[{"name":"a"}],"quotas":[{"provider":"codex","window":" "}]}"#,
        #"{"projects":[{"name":"a"}],"quotas":[{"provider":"codex","window":"primary","used":-0.1}]}"#,
        #"{"projects":[{"name":"a"}],"quotas":[{"provider":"codex","window":"primary","hours":0}]}"#,
        #"{"projects":[{"name":"a"}],"quotas":[{"provider":"codex","window":"primary","resetsInMinutes":0}]}"#,
        #"{"projects":[{"name":"a"}],"quotas":[{"provider":"codex","window":"primary"},{"provider":"codex","window":"primary"}]}"#,
    ])
    func refuses(json: String) {
        do {
            _ = try PreviewScenario.read(Data(json.utf8))
            Issue.record("\(json) was accepted")
        } catch PreviewScenarioError.invalid(let problems) {
            #expect(!problems.isEmpty)
        } catch {
            Issue.record("\(json) failed to read rather than being judged: \(error)")
        }
    }
}
