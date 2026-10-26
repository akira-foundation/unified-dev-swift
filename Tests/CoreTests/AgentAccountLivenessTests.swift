import Foundation
import Synchronization
import Testing
@testable import Core

private final class ScriptedStatus: AgentProcessing, @unchecked Sendable {
    private let continuation: AsyncThrowingStream<String, Error>.Continuation
    private let terminations = Mutex(0)

    let lines: AsyncThrowingStream<String, Error>
    let errorLines = AsyncStream<String> { $0.finish() }

    init(printing output: [String], finishing: Bool = true) {
        var out: AsyncThrowingStream<String, Error>.Continuation!
        lines = AsyncThrowingStream(bufferingPolicy: .unbounded) { out = $0 }
        continuation = out
        for line in output { continuation.yield(line) }
        if finishing { continuation.finish() }
    }

    var terminationCount: Int { terminations.withLock { $0 } }
    var isRunning: Bool { true }
    var exitStatus: Int32 { get async { 0 } }

    func writeLine(_ text: String) {}
    func closeStdin() {}
    func terminate() {
        terminations.withLock { $0 += 1 }
        continuation.finish()
    }
    func kill() { continuation.finish() }
}

private final class Launches: @unchecked Sendable {
    private let seen = Mutex<[AgentLaunch]>([])

    var all: [AgentLaunch] { seen.withLock { $0 } }

    func record(_ launch: AgentLaunch) { seen.withLock { $0.append(launch) } }
}

@Suite("Asking the CLI whether an account has a session")
struct AgentAccountLivenessTests {
    private let claudeHome = AgentAccountHome(
        provider: .claudeCode,
        id: AgentAccountID("work"),
        directory: URL(filePath: "/support/AgentAccounts/claudeCode/work"),
        isDefault: false
    )

    private func liveness(
        printing output: [String],
        environment: [String: String] = [:],
        timeout: Duration = .seconds(5),
        launches: Launches = Launches(),
        process: ScriptedStatus? = nil
    ) -> AgentAccountLiveness {
        AgentAccountLiveness(
            executable: "claude",
            cwd: "/scratch",
            environment: environment,
            timeout: timeout,
            makeProcess: { launch in
                launches.record(launch)
                return process ?? ScriptedStatus(printing: output)
            }
        )
    }

    @Test func aLoggedInAnswerClaimsASession() async {
        let asked = liveness(printing: [#"{"loggedIn":true,"authMethod":"claude.ai"}"#])
        let report = await asked.report(for: claudeHome)
        #expect(report == .claimsSession)
    }

    @Test func aLoggedOutAnswerClaimsNoSession() async {
        let asked = liveness(printing: [#"{"loggedIn":false,"authMethod":"none"}"#])
        let report = await asked.report(for: claudeHome)
        #expect(report == .claimsNoSession)
    }

    @Test func aPrettyPrintedAnswerSpreadOverSeveralLinesIsRead() async {
        let asked = liveness(printing: ["{", #"  "loggedIn": true,"#, #"  "apiProvider": "firstParty""#, "}"])
        let report = await asked.report(for: claudeHome)
        #expect(report == .claimsSession)
    }

    @Test func anAnswerThatIsNotJSONIsUnanswered() async {
        let asked = liveness(printing: ["Not logged in, Please run /login"])
        let report = await asked.report(for: claudeHome)
        #expect(report == .unanswered)
    }

    @Test func aProcessThatSaysNothingIsUnanswered() async {
        let asked = liveness(printing: [])
        let report = await asked.report(for: claudeHome)
        #expect(report == .unanswered)
    }

    @Test func aLoggedInThatIsNotABooleanIsUnanswered() async {
        let asked = liveness(printing: [#"{"loggedIn":"true"}"#])
        let report = await asked.report(for: claudeHome)
        #expect(report == .unanswered)
    }

    @Test func aProcessThatNeverAnswersIsGivenUpOnAndStopped() async {
        let hung = ScriptedStatus(printing: [], finishing: false)
        let asked = liveness(printing: [], timeout: .milliseconds(50), process: hung)
        let report = await asked.report(for: claudeHome)
        #expect(report == .unanswered)
        #expect(hung.terminationCount == 1)
    }

    @Test func aProviderOtherThanClaudeCodeIsNotAskedAnything() async {
        let codex = AgentAccountHome(
            provider: .codex, id: AgentAccountID("work"),
            directory: URL(filePath: "/support/AgentAccounts/codex/work"), isDefault: false
        )
        let launches = Launches()
        let asked = liveness(printing: [#"{"loggedIn":true}"#], launches: launches)
        let report = await asked.report(for: codex)
        #expect(report == .unanswered)
        #expect(launches.all.isEmpty)
    }

    @Test func theCommandIsAimedAtTheAccountDirectoryAndInheritsNoIdentity() async throws {
        let launches = Launches()
        let inherited = [
            "PATH": "/usr/bin",
            "ANTHROPIC_API_KEY": "made-up-key",
            "CLAUDE_CODE_USER_EMAIL": "owner@example.com",
            "CLAUDE_CONFIG_DIR": "/the/hosts/own",
        ]
        let asked = liveness(printing: [#"{"loggedIn":true}"#], environment: inherited, launches: launches)

        _ = await asked.report(for: claudeHome)

        let launch = try #require(launches.all.first)
        #expect(launches.all.count == 1)
        #expect(launch.arguments == ["auth", "status"])
        #expect(launch.environment["CLAUDE_CONFIG_DIR"] == claudeHome.directory.path)
        #expect(launch.environment["ANTHROPIC_API_KEY"] == nil)
        #expect(launch.environment["CLAUDE_CODE_USER_EMAIL"] == nil)
        #expect(launch.environment["PATH"] == "/usr/bin")
    }
}
