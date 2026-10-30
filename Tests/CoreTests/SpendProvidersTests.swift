import Testing
import Foundation
@testable import Core

private let now = Date(timeIntervalSince1970: 1_791_676_800)

private func census(_ kinds: [AgentKind]) -> SpendCensus {
    SpendCensus(providers: Dictionary(
        kinds.map { ($0.rawValue, SpendProviderCensus(keepsTranscripts: true, files: 2, pending: 0)) },
        uniquingKeysWith: { first, _ in first }
    ))
}

@Suite("Spend providers")
struct SpendProvidersTests {
    @Test("a provider signed in on this Mac is listed")
    func signedIn() {
        let found = SpendProviders.onThisMac(
            accounts: [AgentKind.codex: AgentAccount(provider: .codex, observedAt: now)],
            quotas: [],
            unanswered: [],
            withoutLimits: [],
            census: SpendCensus()
        )
        #expect(found == [AgentKind.codex])
    }

    @Test("a provider that reported a limit is listed")
    func reportedALimit() {
        let quota = AgentQuota(
            provider: .claudeCode,
            window: .named("five_hour"),
            measure: .fraction(0.2),
            resetsAt: nil,
            observedAt: now
        )
        let found = SpendProviders.onThisMac(
            accounts: [:], quotas: [quota], unanswered: [], withoutLimits: [], census: SpendCensus()
        )
        #expect(found == [AgentKind.claudeCode])
    }

    @Test("a provider that was asked and said nothing is still listed")
    func asked() {
        #expect(SpendProviders.onThisMac(
            accounts: [:], quotas: [], unanswered: [.grok], withoutLimits: [], census: SpendCensus()
        ) == [AgentKind.grok])
        #expect(SpendProviders.onThisMac(
            accounts: [:], quotas: [], unanswered: [], withoutLimits: [.grok], census: SpendCensus()
        ) == [AgentKind.grok])
    }

    @Test("a provider whose transcripts are on disk is listed even with no account")
    func keepsTranscripts() {
        let found = SpendProviders.onThisMac(
            accounts: [:], quotas: [], unanswered: [], withoutLimits: [], census: census([.claudeCode])
        )
        #expect(found == [AgentKind.claudeCode])
    }

    @Test("a provider this Mac knows nothing about is not listed")
    func unknown() {
        #expect(SpendProviders.onThisMac(
            accounts: [:], quotas: [], unanswered: [], withoutLimits: [], census: SpendCensus()
        ).isEmpty)
    }
}
