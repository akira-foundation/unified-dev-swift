import Testing
import Foundation
@testable import Core

private let now = Date(timeIntervalSince1970: 1_791_676_800)
private let day = Calendar(identifier: .gregorian).startOfDay(for: now)

private let work = AgentAccountHome(
    provider: .claudeCode,
    id: AgentAccountID("work"),
    directory: URL(filePath: "/support/AgentAccounts/claudeCode/work", directoryHint: .isDirectory),
    isDefault: false
)

private let personal = AgentAccountHome(
    provider: .claudeCode,
    id: AgentAccountID("personal"),
    directory: URL(filePath: "/support/AgentAccounts/claudeCode/personal", directoryHint: .isDirectory),
    isDefault: false
)

private func row(
    under account: AgentAccountHome,
    session: String = "a",
    output: Int = 1_000_000,
    provider: AgentKind = .claudeCode
) -> SpendDay {
    row(file: account.directory.path + "/projects/-x/\(session).jsonl", output: output, provider: provider)
}

private func row(file: String, output: Int = 1_000_000, provider: AgentKind = .claudeCode) -> SpendDay {
    SpendDay(
        provider: provider,
        day: day,
        model: "claude-opus-5",
        directory: "/Users/ada/code/billing",
        file: file,
        usage: TokenUsage(output: output),
        turns: 1,
        tier: .base
    )
}

private func input(
    accounts: [AgentAccountHome] = [work, personal],
    identities: [AgentAccountID: AgentAccountIdentity] = [:]
) -> SpendBoard.Input {
    SpendBoard.Input(days: [], accounts: accounts, identities: identities, now: now)
}

@Suite("Spend by account")
struct SpendAccountLineTests {
    private let days = [
        row(under: work, output: 3_000_000),
        row(under: personal, output: 1_000_000),
    ]

    @Test func spendIsGroupedByTheAccountEachTranscriptSitsUnder() {
        let lines = SpendAccountLine.lines(for: days, input: input())
        #expect(lines.count == 2)
        #expect(Set(lines.map(\.accountID)) == [work.id, personal.id])
        #expect(lines.allSatisfy { $0.isKnown })
    }

    @Test func severalTranscriptsOfOneAccountAreSummedWithTheirSessionsKept() {
        let rows = [
            row(under: work, session: "a", output: 1_000_000),
            row(under: work, session: "b", output: 2_000_000),
        ]
        let lines = SpendAccountLine.lines(for: rows, input: input())
        #expect(lines.count == 1)
        #expect(lines[0].sessions.count == 2)
        #expect(lines[0].spend.usage.output == 3_000_000)
        #expect(lines[0].provider == .claudeCode)
    }

    @Test func anAccountIsNamedByItsEmailAndFallsBackToItsDirectory() {
        let identities = [work.id: AgentAccountIdentity(email: "work@client.com")]
        let lines = SpendAccountLine.lines(for: days, input: input(identities: identities))
        #expect(lines.first { $0.accountID == work.id }?.name == "work@client.com")
        #expect(lines.first { $0.accountID == personal.id }?.name == personal.directory.lastPathComponent)
    }

    @Test func anIdentityWithoutAnEmailFallsBackToTheDirectory() {
        let identities = [work.id: AgentAccountIdentity(displayName: "Ada", authMethod: .apiKey)]
        let lines = SpendAccountLine.lines(for: days, input: input(identities: identities))
        #expect(lines.first { $0.accountID == work.id }?.name == work.directory.lastPathComponent)
    }

    @Test func spendUnderARemovedAccountIsStillCountedAndMarkedUnknown() {
        let removed = [row(file: "/support/AgentAccounts/claudeCode/gone/projects/-x/a.jsonl")]
        let lines = SpendAccountLine.lines(for: removed, input: input())
        #expect(lines.count == 1)
        #expect(lines[0].isKnown == false)
        #expect(lines[0].accountID == nil)
        #expect(lines[0].name == SpendAccounts.unknown)
        #expect(lines[0].spend.cost.total > 0)
    }

    @Test func unknownSpendDoesNotFoldIntoAKnownAccount() {
        let rows = days + [row(file: "/support/AgentAccounts/claudeCode/gone/projects/-x/a.jsonl")]
        let lines = SpendAccountLine.lines(for: rows, input: input())
        #expect(lines.count == 3)
        #expect(lines.filter { !$0.isKnown }.count == 1)
        #expect(lines.first { $0.accountID == work.id }?.spend.usage.output == 3_000_000)
    }

    @Test func unknownSpendOfDifferentProvidersStaysInSeparateLines() {
        let rows = [
            row(file: "/gone/a.jsonl", provider: .claudeCode),
            row(file: "/gone/b.jsonl", provider: .codex),
        ]
        let lines = SpendAccountLine.lines(for: rows, input: input())
        #expect(lines.count == 2)
        #expect(Set(lines.map(\.provider)) == [.claudeCode, .codex])
        #expect(Set(lines.map(\.id)).count == 2)
    }

    @Test func twoAccountsWithTheSameEmailStayTwoLines() {
        let shared = AgentAccountIdentity(email: "same@client.com")
        let identities = [work.id: shared, personal.id: shared]
        let lines = SpendAccountLine.lines(for: days, input: input(identities: identities))
        #expect(lines.count == 2)
        #expect(Set(lines.map(\.accountID)) == [work.id, personal.id])
        #expect(Set(lines.map(\.id)).count == 2)
    }

    @Test func linesAreOrderedByCostDescending() {
        let lines = SpendAccountLine.lines(for: days, input: input())
        #expect(lines.map(\.spend.cost.total) == lines.map(\.spend.cost.total).sorted(by: >))
        #expect(lines.first?.accountID == work.id)
    }

    @Test func noAccountsMeansEverythingIsUnknown() {
        let lines = SpendAccountLine.lines(for: days, input: input(accounts: []))
        #expect(lines.count == 1)
        #expect(lines[0].isKnown == false)
        #expect(lines[0].spend.usage.output == 4_000_000)
    }
}
