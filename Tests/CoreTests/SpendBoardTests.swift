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
        agentSessionID: (file as NSString).lastPathComponent,
        file: file,
        usage: usage,
        turns: turns
    )
}

private func census(_ entries: [AgentKind: SpendProviderCensus]) -> SpendCensus {
    SpendCensus(providers: Dictionary(entries.map { ($0.key.rawValue, $0.value) }, uniquingKeysWith: { a, _ in a }))
}

private let measured = SpendProviderCensus(keepsTranscripts: true, files: 3, pending: 0, readAt: now)
private let nothing = SpendProviderCensus(keepsTranscripts: false, files: 0, pending: 0, readAt: now)

@Suite("Spend board")
struct SpendBoardTests {
    @Test("a turn older than the window is left out of it")
    func sevenDayCut() {
        let board = SpendBoard.make(SpendBoard.Input(
            days: [row(0), row(6), row(7), row(30)],
            window: .week,
            now: now,
            calendar: calendar
        ))
        #expect(board.total.usage.output == 2_000_000)
        #expect(board.bars.count == 7)
    }

    @Test("today counts only today")
    func todayCut() {
        let board = SpendBoard.make(SpendBoard.Input(
            days: [row(0), row(1)], window: .today, now: now, calendar: calendar
        ))
        #expect(board.total.usage.output == 1_000_000)
        #expect(board.bars.count == 1)
    }

    @Test("a day with nothing in it still gets a bar")
    func emptyDaysKeepTheirBar() {
        let board = SpendBoard.make(SpendBoard.Input(
            days: [row(3)], window: .week, now: now, calendar: calendar
        ))
        #expect(board.bars.count == 7)
        #expect(board.bars.filter { $0.spend.isEmpty }.count == 6)
        #expect(board.bars.last?.day == day(0))
    }

    @Test("the four columns carry their own share of the tokens and of the cost")
    func columnShares() throws {
        let board = SpendBoard.make(SpendBoard.Input(
            days: [row(0, usage: TokenUsage(cacheRead: 999_000_000, output: 1_000_000))],
            window: .week,
            now: now,
            calendar: calendar
        ))
        let read = try #require(board.columns.first { $0.column == .cacheRead })
        let output = try #require(board.columns.first { $0.column == .output })
        #expect(read.tokenShare > 0.99)
        #expect(output.tokenShare < 0.01)
        #expect(output.costShare > output.tokenShare * 10)
        #expect(read.costShare < read.tokenShare)
    }

    @Test("a provider that keeps no usage on disk says so and does not read as nothing spent")
    func providerWithoutTranscripts() throws {
        let board = SpendBoard.make(SpendBoard.Input(
            days: [row(0)],
            census: census([.claudeCode: measured, .grok: nothing]),
            installed: [.claudeCode, .grok],
            window: .week,
            now: now,
            calendar: calendar
        ))
        let grok = try #require(board.providers.first { $0.kind == .grok })
        #expect(grok.reading == .keepsNoUsage)
        #expect(grok.spend.isEmpty)
        let claude = try #require(board.providers.first { $0.kind == .claudeCode })
        #expect(claude.reading == .measured)
    }

    @Test("a provider that is not installed is not listed")
    func providerNotInstalled() {
        let board = SpendBoard.make(SpendBoard.Input(
            days: [row(0)],
            census: census([.claudeCode: measured]),
            installed: [.claudeCode],
            window: .week,
            now: now,
            calendar: calendar
        ))
        #expect(board.providers.map(\.kind) == [.claudeCode])
    }

    @Test("a provider still being read says so")
    func providerStillReading() throws {
        let board = SpendBoard.make(SpendBoard.Input(
            days: [row(0)],
            census: census([
                .claudeCode: SpendProviderCensus(keepsTranscripts: true, files: 9, pending: 4, readAt: now),
            ]),
            installed: [.claudeCode],
            window: .week,
            now: now,
            calendar: calendar
        ))
        let claude = try #require(board.providers.first)
        #expect(claude.reading == .stillReading(pending: 4))
    }

    @Test("a provider never read yet is not reported as measured")
    func providerNotReadYet() throws {
        let board = SpendBoard.make(SpendBoard.Input(
            days: [], installed: [.codex], window: .week, now: now, calendar: calendar
        ))
        #expect(try #require(board.providers.first).reading == .notRead)
    }

    @Test("the board carries the date the prices were measured on")
    func pricedOn() {
        let board = SpendBoard.make(SpendBoard.Input(days: [], now: now, calendar: calendar))
        #expect(board.pricedOn == ModelPrices.measuredOn)
        #expect(!board.hasSpend)
    }
}

@Suite("Spend lines")
struct SpendLinesTests {
    @Test("a provider whose every turn ran on an unpriced model says so rather than nothing spent")
    func unpricedProviderLine() {
        let spend = ModelPrices.spend(
            of: TokenUsage(freshInput: 10, output: 20), model: "codex-auto-review", provider: .codex
        )
        let line = SpendLines.spendLine(spend)
        #expect(line.contains(SpendLines.noPublishedPrice))
        #expect(!line.contains("$0.00"))
    }

    @Test("a provider with a real cost reads as that cost")
    func pricedProviderLine() {
        let spend = ModelPrices.spend(
            of: TokenUsage(output: 1_000_000), model: "claude-opus-5", provider: .claudeCode
        )
        #expect(SpendLines.spendLine(spend).contains("25"))
    }

    @Test("a provider with nothing in the window says so")
    func emptyProviderLine() {
        #expect(SpendLines.spendLine(.none) == SpendLines.nothingYet)
    }

    @Test("a provider that keeps no usage on disk is never asked for a cost")
    func keepsNoUsageLine() {
        let line = SpendLines.providerLine(SpendBoard.ProviderLine(
            kind: .grok, reading: .keepsNoUsage, spend: .none, turns: 0
        ))
        #expect(line == SpendLines.keepsNoUsage)
    }
}
