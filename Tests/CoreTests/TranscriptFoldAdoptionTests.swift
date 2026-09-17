import Testing
@testable import Core

@Suite("Folding on the pass the row arrived")
struct TranscriptFoldAdoptionTests {
    private static func work(
        firstSeq: Int, rows: Int, ready: Int, upperBound: Int? = nil
    ) -> TranscriptFold.Work {
        let list = (0..<rows).map { TranscriptFold.Row(index: $0, seq: firstSeq + $0) }
        return TranscriptFold.Work(
            span: 0..<(upperBound ?? rows), rows: list, ready: Set(0..<ready), hasAnswer: false
        )
    }

    private static func folds(_ all: [TranscriptFold.Work]) -> TranscriptFold.Folds {
        TranscriptFold.Folds(all: all, scannedRows: 0, resumeIndex: 0)
    }

    @Test func adoptsAPassThatOnlyTakesRowsOutOfTheTail() {
        let stale = Self.folds([Self.work(firstSeq: 10, rows: 4, ready: 3)])
        let fresh = Self.folds([Self.work(firstSeq: 10, rows: 4, ready: 4)])

        #expect(TranscriptFold.mayAdopt(fresh, over: stale, drawn: 0..<40))
    }

    @Test func adoptsCompletedActionsAfterARunningCommand() {
        var old = Self.work(firstSeq: 10, rows: 5, ready: 0)
        old.ready = [1, 2, 3]
        var new = old
        new.ready.insert(4)

        #expect(TranscriptFold.mayAdopt(Self.folds([new]), over: Self.folds([old]), drawn: 0..<40))
    }

    @Test func refusesANewRunningActionAfterCompletedActions() {
        var old = Self.work(firstSeq: 10, rows: 4, ready: 0)
        old.ready = [1, 2, 3]
        var new = Self.work(firstSeq: 10, rows: 5, ready: 0)
        new.ready = old.ready

        #expect(!TranscriptFold.mayAdopt(Self.folds([new]), over: Self.folds([old]), drawn: 0..<40))
    }

    @Test func refusesAPassThatPutsANewRowInTheTail() {
        let stale = Self.folds([Self.work(firstSeq: 10, rows: 4, ready: 3)])
        let fresh = Self.folds([Self.work(firstSeq: 10, rows: 5, ready: 4)])

        #expect(!TranscriptFold.mayAdopt(fresh, over: stale, drawn: 0..<40))
    }

    @Test func refusesAPlainArrival() {
        let stale = Self.folds([Self.work(firstSeq: 10, rows: 4, ready: 4)])
        let fresh = Self.folds([Self.work(firstSeq: 10, rows: 5, ready: 4)])

        #expect(!TranscriptFold.mayAdopt(fresh, over: stale, drawn: 0..<40))
    }

    @Test func refusesAFoldThatDidNotExistYet() {
        let stale = Self.folds([])
        let fresh = Self.folds([Self.work(firstSeq: 10, rows: 4, ready: 4)])

        #expect(!TranscriptFold.mayAdopt(fresh, over: stale, drawn: 0..<40))
    }

    @Test func refusesAWorkingThatRunsPastTheDrawnWindow() {
        let stale = Self.folds([Self.work(firstSeq: 10, rows: 4, ready: 3, upperBound: 4)])
        let fresh = Self.folds([Self.work(firstSeq: 10, rows: 4, ready: 4, upperBound: 41)])

        #expect(!TranscriptFold.mayAdopt(fresh, over: stale, drawn: 0..<40))
    }

    @Test func refusesADifferentTurnAltogether() {
        let stale = Self.folds([Self.work(firstSeq: 10, rows: 4, ready: 3)])
        let fresh = Self.folds([Self.work(firstSeq: 99, rows: 4, ready: 4)])

        #expect(!TranscriptFold.mayAdopt(fresh, over: stale, drawn: 0..<40))
    }
}
