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

    private struct Absent: AgentQuotaSource {
        static let provider = AgentKind.codex
        static let reportedAt = Date(timeIntervalSince1970: 1_790_000_000)

        func read() async -> Data? { nil }

        func standing() async -> QuotaStanding {
            QuotaStanding(isInstalled: false, lastReportedAt: Self.reportedAt)
        }
    }

    private struct Lapsed: AgentQuotaSource {
        static let provider = AgentKind.claudeCode
        static let reportedAt = Date(timeIntervalSince1970: 1_790_859_223)

        func read() async -> Data? { nil }

        func standing() async -> QuotaStanding {
            QuotaStanding(isInstalled: true, lastReportedAt: Self.reportedAt)
        }
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

    @Test("an agent that is not installed is left out whole, stamp and all")
    func absentIsNotSilent() async {
        let report = await AgentQuotaSources.report([Absent()])
        #expect(report.unanswered.isEmpty)
        #expect(report.lastReported.isEmpty)
    }

    @Test("when a source cannot answer, the report still carries when it last reported")
    func carriesTheLastReport() async {
        let report = await AgentQuotaSources.report([Lapsed()])
        #expect(Set(report.unanswered) == [.claudeCode])
        #expect(report.lastReported == [.claudeCode: Lapsed.reportedAt])
    }
}
