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

@Suite("Spend by provider and day")
struct SpendSliceTests {
    @Test("a day with two providers is two slices, one each")
    func twoProvidersOneDay() {
        let board = SpendBoard.make(SpendBoard.Input(
            days: [row(0), row(0, provider: .codex, model: "gpt-6-sol", file: "/t/b.jsonl")],
            window: .week,
            now: now,
            calendar: calendar
        ))
        #expect(board.slices.count == 2)
        #expect(Set(board.slices.map(\.provider)) == [.claudeCode, .codex])
        #expect(board.slices.allSatisfy { $0.day == day(0) })
    }

    @Test("the slices of a day add up to that day's bar")
    func slicesAddUpToTheBar() throws {
        let board = SpendBoard.make(SpendBoard.Input(
            days: [row(1), row(1, provider: .codex, model: "gpt-6-sol", file: "/t/b.jsonl")],
            window: .week,
            now: now,
            calendar: calendar
        ))
        let bar = try #require(board.bars.first { $0.day == day(1) })
        let slices = board.slices.filter { $0.day == day(1) }
        #expect(Spend.sum(slices.map(\.spend)).cost.total == bar.spend.cost.total)
    }

    @Test("a slice carries one provider's spend, not the day's")
    func sliceIsOneProvider() throws {
        let board = SpendBoard.make(SpendBoard.Input(
            days: [
                row(0, usage: TokenUsage(output: 1_000_000)),
                row(0, provider: .codex, model: "gpt-6-sol", file: "/t/b.jsonl", usage: TokenUsage(output: 2_000_000)),
            ],
            window: .week,
            now: now,
            calendar: calendar
        ))
        let claude = try #require(board.slices.first { $0.provider == .claudeCode })
        #expect(claude.spend.usage.output == 1_000_000)
    }

    @Test("every provider has a colour of its own")
    func everyProviderHasAColour() {
        let hexes = AgentKind.allCases.map(ProviderAccent.hex(for:))
        #expect(Set(hexes).count == AgentKind.allCases.count)
        #expect(hexes.allSatisfy { Accent.all.contains($0) })
    }
}
