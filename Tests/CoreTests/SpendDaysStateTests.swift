import Testing
import Foundation
@testable import Core

@Suite("Spend days state", .tags(.persistence))
struct SpendDaysStateTests {
    private struct BrokenRead: Error {}

    private let now = Date(timeIntervalSince1970: 1_793_000_000)

    private var today: Date { Calendar.current.startOfDay(for: now) }

    private func day(_ turns: Int) -> SpendDay {
        SpendDay(
            provider: .claudeCode, day: today, model: "claude-opus-5", directory: "/Users/ada/work", file: "a.jsonl",
            usage: TokenUsage(freshInput: 1_000_000, output: 1_000_000), turns: turns, tier: .base
        )
    }

    private var cursor: TranscriptCursor {
        TranscriptCursor(path: "/t/a.jsonl", provider: .claudeCode, size: 100, modifiedAt: now, offset: 10)
    }

    private func turn(_ key: String, at date: Date) -> SpendTurn {
        SpendTurn(
            file: "/t/a.jsonl", key: key, provider: .claudeCode, day: date, model: "claude-opus-5",
            directory: "/Users/ada/work", tier: .base, usage: TokenUsage(freshInput: 1, output: 5)
        )
    }

    private func board(_ state: SpendDaysState) -> SpendBoard {
        SpendBoard.make(SpendBoard.Input(days: state.days, standing: state.standing, window: .week, now: now))
    }

    private func read(_ days: [SpendDay]) -> SpendDaysState {
        var state = SpendDaysState()
        state.apply(.success(days))
        return state
    }

    @Test func aFailedReadKeepsTheDaysOfTheLastGoodOne() {
        var state = read([day(3)])

        state.apply(.failure(BrokenRead()))

        #expect(state.days == [day(3)])
        #expect(state.standing == .kept)
    }

    @Test func aSecondFailedReadStillKeepsThem() {
        var state = read([day(3)])

        state.apply(.failure(BrokenRead()))
        state.apply(.failure(BrokenRead()))

        #expect(state.days == [day(3)])
        #expect(state.standing == .kept)
    }

    @Test func aGoodReadAfterAFailedOneIsCurrentAndReplacesTheDays() {
        var state = read([day(3)])
        state.apply(.failure(BrokenRead()))

        state.apply(.success([day(5)]))

        #expect(state.days == [day(5)])
        #expect(state.standing == .current)
    }

    @Test func anEmptyGoodReadIsAnEmptyWindowAndNotAFailure() {
        var state = read([day(3)])

        state.apply(.success([]))

        #expect(state.days.isEmpty)
        #expect(state.standing == .current)
    }

    @Test func aFailedFirstReadIsAFailureAndNeverAnEmptyWindow() {
        var state = SpendDaysState()

        state.apply(.failure(BrokenRead()))

        #expect(state.standing == .failed)
        #expect(!state.standing.knowsTheFigures)
    }

    @Test func aScreenThatCouldNotReadDoesNotClaimAnEmptyWindowOrAZeroTotal() {
        var state = SpendDaysState()
        state.apply(.failure(BrokenRead()))
        let failed = board(state)

        #expect(SpendLines.dearestLine(failed) == SpendLines.daysFailed)
        #expect(failed.emptyLine == SpendLines.daysFailed)
        #expect(SpendLines.total(failed) == SpendLines.totalUnknown)
        #expect(SpendLines.money(failed) == SpendLines.totalUnknown)
    }

    @Test func keepingTheFiguresShowsThemAndSaysTheyMayBeBehind() {
        var state = read([day(3)])
        state.apply(.failure(BrokenRead()))
        let kept = board(state)

        #expect(kept.total.usage.output == 1_000_000)
        #expect(SpendLines.total(kept) == SpendLines.cost(kept.total))
        #expect(SpendLines.dearestLine(kept) == SpendLines.daysBehind)
    }

    @Test func anEmptyCurrentReadStillSaysThereAreNoTurns() {
        let empty = board(read([]))

        #expect(SpendLines.dearestLine(empty) == SpendBoard.emptyLine)
        #expect(empty.emptyLine == SpendBoard.emptyLine)
        #expect(SpendLines.total(empty) == SpendLines.cost(empty.total))
    }

    @Test func theAccountTableOfAWindowNothingReadFailsInsteadOfSayingNoTurns() async throws {
        let store = try makeTestStore("spend-days-state")
        var failed = SpendBoard.Input(days: [], standing: .failed, window: .week, now: now)
        #expect(await SpendBoard.accountsState(failed, reading: store, defaults: []) == .failed)

        failed.standing = .notRead
        #expect(await SpendBoard.accountsState(failed, reading: store, defaults: []) == .notRead)

        failed.standing = .kept
        #expect(await SpendBoard.accountsState(failed, reading: store, defaults: []) == .failed)

        failed.standing = .current
        #expect(await SpendBoard.accountsState(failed, reading: store, defaults: []) == .read([]))
    }

    @Test func aStoreThatCannotReadTheDaysKeepsThePreviousOnes() async throws {
        let store = try makeTestStore("spend-days-state")
        var state = read([day(3)])
        let other = try SQLiteDatabase(path: store.path)
        _ = try other.run("DROP TABLE usage_turns")

        state.apply(await SpendDaysState.read(store, since: Date(timeIntervalSince1970: 0)))

        #expect(state.days == [day(3)])
        #expect(state.standing == .kept)
    }

    @Test func aReadableStoreGivesItsDaysFromTheDayAsked() async throws {
        let store = try makeTestStore("spend-days-state")
        try await store.record([turn("recent", at: now), turn("old", at: now.addingTimeInterval(-40 * 86_400))], reaching: cursor)
        var state = SpendDaysState()

        state.apply(await SpendDaysState.read(store, since: now.addingTimeInterval(-86_400)))

        #expect(state.days.count == 1)
        #expect(state.standing == .current)
    }

    @Test func aScreenThatCouldNotReadDrawsNoZeroFigures() {
        var state = SpendDaysState()
        state.apply(.failure(BrokenRead()))
        let failed = SpendBoard.make(SpendBoard.Input(
            days: state.days, standing: state.standing, installed: [.claudeCode], window: .week, now: now
        ))
        let current = SpendBoard.make(SpendBoard.Input(days: [], installed: [.claudeCode], window: .week, now: now))

        #expect(failed.columns.isEmpty)
        #expect(failed.providers.isEmpty)
        #expect(failed.bars.isEmpty)
        #expect(!current.columns.isEmpty)
        #expect(!current.bars.isEmpty)
        #expect(!current.providers.isEmpty)
    }

    @Test func aScreenStillReadingDoesNotClaimAFigureOrAnEmptyWindow() {
        let reading = board(SpendDaysState())

        #expect(!SpendDaysState().standing.knowsTheFigures)
        #expect(SpendLines.total(reading) == SpendLines.totalUnknown)
        #expect(SpendLines.dearestLine(reading) == SpendLines.daysNotRead)
    }

    @Test func keptFiguresAreStillShownInTheMenuBar() {
        var state = read([day(3)])
        state.apply(.failure(BrokenRead()))
        let kept = board(state)

        #expect(SpendLines.money(kept) == SpendFormat.money(kept.total.cost.total))
        #expect(!kept.columns.isEmpty)
    }
}
