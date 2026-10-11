import Testing
import Foundation
@testable import Core

private var calendar: Calendar {
    var made = Calendar(identifier: .gregorian)
    made.timeZone = TimeZone(secondsFromGMT: 0)!
    return made
}

private let now = Date(timeIntervalSince1970: 1_791_676_800)

private func day(_ daysAgo: Int) -> Date {
    calendar.date(byAdding: .day, value: -daysAgo, to: calendar.startOfDay(for: now))!
}

private func row(
    _ daysAgo: Int,
    provider: AgentKind = .claudeCode,
    model: String = "claude-opus-5",
    directory: String = "/Users/ada/work",
    file: String = "/t/one.jsonl",
    usage: TokenUsage = TokenUsage(freshInput: 1_000_000, output: 1_000_000),
    turns: Int = 1
) -> SpendDay {
    SpendDay(
        provider: provider,
        day: day(daysAgo),
        model: model,
        directory: directory,
        file: file,
        usage: usage,
        turns: turns,
        tier: .base
    )
}

private func census(_ entries: [AgentKind: SpendProviderCensus]) -> SpendCensus {
    SpendCensus(providers: Dictionary(entries.map { ($0.key.rawValue, $0.value) }, uniquingKeysWith: { a, _ in a }))
}

private let measured = SpendProviderCensus(keepsTranscripts: true, files: 3, pending: 0)
private let nothing = SpendProviderCensus(keepsTranscripts: false, files: 0, pending: 0)

@Suite("Spend lines")
struct SpendLinesTests {
    @Test("a provider whose every turn ran on an unpriced model says so rather than nothing spent")
    func unpricedProviderLine() {
        let spend = ModelPrices.spend(
            of: TokenUsage(freshInput: 10, output: 20), model: "codex-auto-review", provider: .codex
        )
        let line = SpendLines.cost(spend)
        #expect(line.contains(SpendLines.noPublishedPrice))
        #expect(!line.contains("$0.00"))
    }

    @Test("a provider with a real cost reads as that cost")
    func pricedProviderLine() {
        let spend = ModelPrices.spend(
            of: TokenUsage(output: 1_000_000), model: "claude-opus-5", provider: .claudeCode
        )
        #expect(spend.cost.total == 25)
        #expect(SpendLines.cost(spend) == SpendFormat.money(25))
    }

    @Test("a provider with nothing in the window says so")
    func emptyProviderLine() {
        let line = SpendLines.providerLine(SpendBoard.ProviderLine(
            kind: .claudeCode, reading: .measured, spend: .none, turns: 0, files: 2
        ))
        #expect(line == SpendLines.nothingYet)
    }

    @Test("a provider still being read says how many transcripts are left of how many")
    func stillReadingLine() {
        let line = SpendLines.providerLine(SpendBoard.ProviderLine(
            kind: .claudeCode, reading: .stillReading(pending: 4), spend: .none, turns: 0, files: 112
        ))
        #expect(line == "still reading 4 of 112 transcripts")
    }

    @Test("one of a thing is named in the singular")
    func singulars() {
        #expect(SpendLines.turns(1) == "1 turn")
        #expect(SpendLines.turns(2) == "2 turns")
        #expect(SpendLines.sessions(1) == "1 chat")
        #expect(SpendLines.sessions(2) == "2 chats")
        #expect(SpendLines.stillReading(1, of: 1) == "still reading 1 transcript")
        #expect(SpendLines.stillReading(2, of: 2) == "still reading 2 transcripts")
    }

    @Test("a provider never read yet says so rather than nothing spent")
    func notReadLine() {
        let line = SpendLines.providerLine(SpendBoard.ProviderLine(
            kind: .codex, reading: .notRead, spend: .none, turns: 0, files: 0
        ))
        #expect(line == SpendLines.notRead)
    }

    @Test("a provider that keeps no usage on disk is never asked for a cost")
    func keepsNoUsageLine() {
        let line = SpendLines.providerLine(SpendBoard.ProviderLine(
            kind: .grok, reading: .keepsNoUsage, spend: .none, turns: 0, files: 0
        ))
        #expect(line == SpendLines.keepsNoUsage)
    }
}
