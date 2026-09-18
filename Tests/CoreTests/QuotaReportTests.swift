import Foundation
import Testing
@testable import Core

@Suite("Quota report")
struct QuotaReportTests {
    private struct Answering: AgentQuotaSource {
        static let provider = AgentKind.claudeCode

        func read() async -> Data? {
            Data(#"{"session":{},"rate_limits_available":false}"#.utf8)
        }
    }

    private struct Silent: AgentQuotaSource {
        static let provider = AgentKind.codex

        func read() async -> Data? { nil }
    }

    @Test("a source that gives no answer is named, and one that answers is not")
    func namesTheSilentOne() async {
        let report = await AgentQuotaSources.report([Answering(), Silent()])
        #expect(Set(report.unanswered) == [.codex])
        #expect(report.accounts.map(\.provider) == [.claudeCode])
    }

    @Test("when everyone answers nobody is named")
    func nobodySilent() async {
        let report = await AgentQuotaSources.report([Answering()])
        #expect(report.unanswered.isEmpty)
    }
}
