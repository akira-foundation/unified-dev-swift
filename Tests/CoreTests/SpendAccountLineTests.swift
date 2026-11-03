import Testing
import Foundation
@testable import Core

private let now = Date(timeIntervalSince1970: 1_791_676_800)
private let day = Calendar(identifier: .gregorian).startOfDay(for: now)

private let work = AgentAccountHome(
    provider: .claudeCode,
    id: AgentAccountID("work"),
    directory: URL(filePath: "/Users/ada/.claude-work", directoryHint: .isDirectory),
    isDefault: false
)

private let personal = AgentAccountHome(
    provider: .claudeCode,
    id: AgentAccountID("personal"),
    directory: URL(filePath: "/Users/ada/.claude", directoryHint: .isDirectory),
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
        let removed = [row(file: "/Users/ada/.claude-gone/projects/-x/a.jsonl")]
        let lines = SpendAccountLine.lines(for: removed, input: input())
        #expect(lines.count == 1)
        #expect(lines[0].isKnown == false)
        #expect(lines[0].accountID == nil)
        #expect(lines[0].name == SpendAccounts.unknown)
        #expect(lines[0].spend.cost.total > 0)
    }

    @Test func unknownSpendDoesNotFoldIntoAKnownAccount() {
        let rows = days + [row(file: "/Users/ada/.claude-gone/projects/-x/a.jsonl")]
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

    @Test func aKnownLineTakesItsProviderFromTheAccountAndNotFromTheRow() {
        let rows = [row(under: work, session: "a"), row(under: work, session: "b", provider: .codex)]
        let lines = SpendAccountLine.lines(for: rows, input: input())
        #expect(lines.count == 1)
        #expect(lines[0].provider == .claudeCode)
    }

    @Test func anEmptyEmailFallsBackToTheDirectoryRatherThanNamingTheRowNothing() {
        let identities = [work.id: AgentAccountIdentity(email: "")]
        let lines = SpendAccountLine.lines(for: days, input: input(identities: identities))
        #expect(lines.first { $0.accountID == work.id }?.name == work.directory.lastPathComponent)
    }

    @Test func linesOfEqualCostAreOrderedByNameAndThenById() {
        let identities = [
            work.id: AgentAccountIdentity(email: "zoe@client.com"),
            personal.id: AgentAccountIdentity(email: "ada@client.com"),
        ]
        let even = [row(under: work, output: 1_000_000), row(under: personal, output: 1_000_000)]
        let lines = SpendAccountLine.lines(for: even, input: input(identities: identities))
        #expect(lines.map(\.name) == ["ada@client.com", "zoe@client.com"])
    }

    @Test func twoUnknownLinesOfEqualCostKeepAStableOrder() {
        let rows = [
            row(file: "/Users/ada/.claude-gone/a.jsonl", provider: .codex),
            row(file: "/Users/ada/.claude-gone/b.jsonl", provider: .claudeCode),
        ]
        let lines = SpendAccountLine.lines(for: rows, input: input())
        #expect(lines.map(\.id) == lines.map(\.id).sorted())
        #expect(lines.map(\.provider) == [.claudeCode, .codex])
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

    @Test func theUnknownLineTotalsExactlyTheRowsThatWentIntoIt() {
        let orphans = [
            row(file: "/Users/ada/.claude-gone/a.jsonl", output: 2_000_000),
            row(file: "/Users/ada/.claude-gone/b.jsonl", output: 500_000),
        ]
        let lines = SpendAccountLine.lines(for: days + orphans, input: input())
        let unknown = lines.filter { !$0.isKnown }
        let expected = Spend.sum(orphans.map(\.spend))
        #expect(unknown.count == 1)
        #expect(unknown[0].spend == expected)
        #expect(unknown[0].sessions.count == 2)
    }

    @Test func everyInputRowIsCountedExactlyOnceAcrossAllLines() {
        let sharedUnknownFile = "/Users/ada/.claude-gone/shared.jsonl"
        let rows = [
            row(under: work, session: "a", output: 1_000_000),
            row(under: work, session: "b", output: 2_000_000),
            row(under: personal, session: "c", output: 4_000_000),
            row(file: sharedUnknownFile, output: 8_000_000),
            row(file: sharedUnknownFile, output: 16_000_000),
            row(file: "/Users/ada/.claude-gone/other.jsonl", output: 32_000_000),
            row(file: "/gone/codex.jsonl", output: 64_000_000, provider: .codex),
            row(file: "/gone/codex-too.jsonl", output: 128_000_000, provider: .codex),
        ]
        let lines = SpendAccountLine.lines(for: rows, input: input())
        let counted = Spend.sum(lines.map(\.spend))
        let supplied = Spend.sum(rows.map(\.spend))
        #expect(lines.filter { !$0.isKnown }.count == 2)
        #expect(counted.usage == supplied.usage)
        #expect(abs(counted.cost.total - supplied.cost.total) < 0.000_001)
        #expect(lines.reduce(0) { $0 + $1.sessions.count } == 7)
    }
}
