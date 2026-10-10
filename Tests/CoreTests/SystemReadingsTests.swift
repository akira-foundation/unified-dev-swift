import Foundation
import Testing
@testable import Core

@Suite("What the app reads about this Mac")
struct SystemReadingsTests {
    @Test("a fact that does not look like what it claims to be is dropped, not published")
    func hostileValuesAreDropped() {
        let appVersion = SystemReadings.checked(
            "/Users/someone/dev", SystemReadings.appVersionPattern, or: ""
        )
        let macOS = SystemReadings.checked(
            "26.1.0 on kid-macbook", SystemReadings.systemVersionPattern, or: ""
        )
        let agent = SystemReadings.checked("/Users/someone/bin/claude", Feedback.slugPattern, or: "")
        let locale = SystemReadings.checked("someone@example.com", Feedback.localePattern, or: "")

        #expect(appVersion.isEmpty)
        #expect(macOS.isEmpty)
        #expect(agent.isEmpty)
        #expect(locale.isEmpty)
    }

    @Test("a fact that does look right is kept, trimmed of the space around it")
    func goodValuesSurvive() {
        #expect(SystemReadings.checked(" 1.4.0 ", SystemReadings.appVersionPattern, or: "") == "1.4.0")
        #expect(SystemReadings.checked("26.1.0", SystemReadings.systemVersionPattern, or: "") == "26.1.0")
    }

    @Test("an environment built from hostile values carries none of them")
    func theEnvironmentScrubsWhatItIsHanded() {
        let environment = FeedbackFixture.environment(
            appVersion: "/Users/someone/dev/code",
            appBuild: "sk-ant-api03-secret",
            macOSVersion: "26.1.0 (kid-macbook.local)",
            agent: "claude at /Users/someone",
            agentVersion: "someone@example.com",
            availableAgents: ["/Users/someone/bin/codex"],
            permissionMode: "accept-edits",
            locale: "Projecto Interno"
        )
        let written = environment.fields.map { "\($0.name) \($0.value)" }.joined(separator: "\n")

        #expect(!written.contains("someone"))
        #expect(!written.contains("sk-ant"))
        #expect(!written.contains("macbook"))
        #expect(!written.contains("Projecto"))
        #expect(written.contains("accept-edits"))
    }

    @Test("a macOS version is three numbers, and an impossible one is brought into range")
    func macOSVersionIsThreeNumbers() {
        #expect(SystemReadings.macOSVersion(major: 26, minor: 1, patch: 0) == "26.1.0")
        #expect(SystemReadings.macOSVersion(major: 40_000, minor: -3, patch: 0) == "999.0.0")
    }

    @Test("the agent name is every runnable agent installed, in the catalogue's order")
    func agentNameIsWhatCanRun() {
        #expect(SystemReadings.agentName(installed: []) == SystemReadings.noAgent)
        #expect(SystemReadings.agentName(installed: [.claudeCode]) == "claude")

        let both = SystemReadings.agentName(installed: [.codex, .claudeCode])
        let ordered = AgentKind.allCases
            .filter { $0.canRunWorkspaces && [AgentKind.codex, .claudeCode].contains($0) }
            .map(SystemReadings.wireName)
            .joined(separator: "_")

        #expect(both == ordered)
        #expect(both.contains("_"))
    }

    @Test("an agent that cannot run a workspace is not the agent this Mac reports")
    func onlyRunnableAgentsCount() {
        let unrunnable = AgentKind.allCases.filter { !$0.canRunWorkspaces }

        for kind in unrunnable {
            #expect(SystemReadings.agentName(installed: [kind]) == SystemReadings.noAgent)
        }
    }

    @Test("the theme is read from the key the appearance setting already uses")
    func themeReadsTheExistingPreference() {
        let defaults = TestDefaults.make("system-readings-theme").defaults
        defaults.set("dark", forKey: SystemReadings.Theme.defaultsKey)

        #expect(SystemReadings.Theme.defaultsKey == "appearance")
        #expect(SystemReadings.Theme(in: defaults) == .dark)
    }

    @Test("a theme the app does not know is the system one, not a crash")
    func themeFallsBack() {
        #expect(SystemReadings.Theme(defaultsValue: nil) == .system)
        #expect(SystemReadings.Theme(defaultsValue: "") == .system)
        #expect(SystemReadings.Theme(defaultsValue: "/Users/someone") == .system)
    }
}

@Suite("Whether a report carries the logs")
struct FeedbackLogPreferenceTests {
    @Test("the logs go by default, because a report without them is harder to act on")
    func onByDefault() {
        #expect(Feedback.includesLogs(TestDefaults.make("feedback-logs-default").defaults))
        #expect(Feedback.includesLogsByDefault)
    }

    @Test("unticking the box is remembered for the next report")
    func theChoiceIsRemembered() {
        let defaults = TestDefaults.make("feedback-logs-remembered").defaults
        Feedback.rememberIncludesLogs(false, in: defaults)

        #expect(!Feedback.includesLogs(defaults))

        Feedback.rememberIncludesLogs(true, in: defaults)
        #expect(Feedback.includesLogs(defaults))
    }
}
