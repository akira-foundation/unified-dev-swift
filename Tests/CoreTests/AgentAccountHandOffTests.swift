import Testing
import Foundation
@testable import Core

@Suite("A resolved account reaches the sources that read per account", .scratchDirectory)
struct AgentAccountHandOffTests {
    private func accountHome(writing identity: String) throws -> AgentAccountHome {
        let directory = TestScratch.unique("account")
        try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
        try Data(identity.utf8).write(to: URL(filePath: directory).appending(path: ".claude.json"))
        return AgentAccountHome(
            provider: .claudeCode,
            id: AgentAccountID("work"),
            directory: URL(filePath: directory, directoryHint: .isDirectory),
            isDefault: false
        )
    }

    @Test func theClaudeModelListIsReadFromTheChosenAccountsOwnFile() async throws {
        let home = try accountHome(writing: #"{"additionalModelOptionsCache":[{"value":"only-on-work-1","label":"Work only"}]}"#)

        let sources = AgentModelSource.live(accounts: [.claudeCode: home])
        let models = try await #require(sources[.claudeCode]).models()

        #expect(models.contains { $0.id == "only-on-work-1" })
    }

    @Test func withoutAnAccountTheClaudeModelListDoesNotReadThatFile() async throws {
        _ = try accountHome(writing: #"{"additionalModelOptionsCache":[{"value":"only-on-work-1","label":"Work only"}]}"#)

        let sources = AgentModelSource.live()
        let models = try await #require(sources[.claudeCode]).models()

        #expect(!models.contains { $0.id == "only-on-work-1" })
    }

    @Test func theClaudeQuotaFreshnessIsReadFromTheChosenAccountsOwnFile() async throws {
        let stampMs = (Date().timeIntervalSince1970 - 60) * 1000
        let home = try accountHome(
            writing: #"{"cachedUsageUtilization":{"fetchedAtMs":\#(stampMs),"utilization":{}}}"#
        )

        let sources = AgentQuotaSources.all(accounts: [.claudeCode: home])
        let claude = try #require(sources.first { type(of: $0).provider == .claudeCode })
        let standing = await claude.standing()

        let reported = try #require(standing.lastReportedAt)
        #expect(abs(reported.timeIntervalSince1970 * 1000 - stampMs) < 1)
    }
}
