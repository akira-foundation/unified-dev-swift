import Foundation
import Testing
@testable import Core

@Suite("Folding a turn's working")
struct TranscriptFoldTests {
    private func tool(
        _ seq: Int, failed: Bool = false, settled: Bool = true, fresh: Bool = false
    ) -> TranscriptFold.Fact {
        TranscriptFold.Fact(seq: seq, kind: .toolUse, failed: failed, settled: settled, isFresh: fresh)
    }

    private func prose(_ seq: Int) -> TranscriptFold.Fact {
        TranscriptFold.Fact(seq: seq, kind: .assistantText)
    }

    private func thinking(_ seq: Int) -> TranscriptFold.Fact {
        TranscriptFold.Fact(seq: seq, kind: .thinking)
    }

    private func notice(_ seq: Int) -> TranscriptFold.Fact {
        TranscriptFold.Fact(seq: seq, kind: .notice)
    }

    private func ask(_ seq: Int, decided: Bool = true) -> TranscriptFold.Fact {
        TranscriptFold.Fact(seq: seq, kind: .permissionAsk, settled: decided)
    }

    private func failure(_ seq: Int) -> TranscriptFold.Fact {
        TranscriptFold.Fact(seq: seq, kind: .error)
    }

    private func quiet(_ seq: Int) -> TranscriptFold.Fact {
        TranscriptFold.Fact(seq: seq, kind: .system, drawsNothing: true)
    }

    private func user(_ seq: Int) -> TranscriptFold.Fact {
        TranscriptFold.Fact(seq: seq, kind: .user)
    }

    private func footer(_ seq: Int) -> TranscriptFold.Fact {
        TranscriptFold.Fact(seq: seq, kind: .result)
    }

    private let everything = 0..<1_000

    private func hides(_ work: TranscriptFold.Work, revealed: Set<Int> = []) -> Int {
        TranscriptFold.hiddenIndices(work, revealed: revealed, drawn: everything).count
    }

    private func only(_ facts: [TranscriptFold.Fact]) throws -> TranscriptFold.Work {
        let folds = TranscriptFold.folds(in: facts)
        #expect(folds.all.count == 1)
        return try #require(folds.all.first)
    }

    @Test("assistant prose remains visible between consecutive activity groups")
    func proseSeparatesActivity() {
        let facts = [user(0)]
            + (1..<4).map { tool($0) } + [prose(4)]
            + (5..<8).map { tool($0) } + [notice(8)]
            + (9..<12).map { tool($0) } + [prose(12), footer(13)]
        let folds = TranscriptFold.folds(in: facts)
        #expect(folds.all.map(\.span) == [1..<4, 5..<12])
        #expect(folds.all.map(\.rows.count) == [3, 7])
        #expect(folds.all.map(\.hasAnswer) == [true, true])
        #expect(folds.all.map { hides($0) } == [3, 7])
    }

    @Test("thinking, a subagent's rows and the stream events between them all fold")
    func everythingBetweenFolds() throws {
        let facts = [user(0), thinking(1), quiet(2), tool(3), quiet(4), tool(5), prose(6), footer(7)]
        let work = try only(facts)
        #expect(work.rows.map(\.seq) == [1, 3, 5])
        #expect(work.span == 1..<6)
        #expect(hides(work) == 3)
    }

    @Test("user messages, assistant prose and turn footers are boundaries")
    func theBoundaries() {
        let facts = [user(0)]
            + (1..<5).map { tool($0) } + [prose(5), footer(6), user(7)]
            + (8..<12).map { tool($0) } + [prose(12)]
        let folds = TranscriptFold.folds(in: facts)
        #expect(folds.all.count == 2)
        #expect(folds.all.map(\.span) == [1..<5, 8..<12])
    }

    @Test("two prose blocks divide the activity around them")
    func twoProseBlocks() {
        let facts = [user(0), tool(1), tool(2), prose(3), tool(4), tool(5), prose(6), footer(7)]
        let folds = TranscriptFold.folds(in: facts)
        #expect(folds.all.map { $0.rows.map(\.seq) } == [[1, 2], [4, 5]])
        #expect(folds.all.map(\.hasAnswer) == [true, true])
    }

    @Test("a turn that ends on settled work includes its newest row in the fold")
    func noAnswer() throws {
        let facts = [user(0)] + (1..<8).map { tool($0) } + [footer(8)]
        let work = try only(facts)
        #expect(!work.hasAnswer)
        #expect(hides(work) == 7)
        #expect(work.rows[hides(work) - 1].seq == 7)
    }

    @Test("prose before more work stays outside both activity groups")
    func proseThenWork() {
        let facts = [user(0), tool(1), tool(2), prose(3), tool(4), tool(5), tool(6), footer(7)]
        let folds = TranscriptFold.folds(in: facts)
        #expect(folds.all.map { $0.rows.map(\.seq) } == [[1, 2], [4, 5, 6]])
        #expect(folds.all.map(\.hasAnswer) == [true, false])
    }

    @Test("a notice after the answer keeps the answer out of the fold")
    func noticeAfterTheAnswer() throws {
        let facts = [user(0)] + (1..<6).map { tool($0) } + [prose(6), notice(7), footer(8)]
        let work = try only(facts)
        #expect(work.hasAnswer)
        #expect(work.span == 1..<6)
    }

    @Test("a tail with no prose in it is not an answer")
    func aTailWithoutProse() throws {
        let facts = [user(0)] + (1..<7).map { tool($0) } + [quiet(7), footer(8)]
        let work = try only(facts)
        #expect(!work.hasAnswer)
    }

    @Test("a working shorter than three rows hides nothing")
    func theThreshold() {
        func turn(of count: Int) -> [TranscriptFold.Fact] {
            [user(0)] + (1...count).map { tool($0) } + [prose(count + 1), footer(count + 2)]
        }
        #expect(TranscriptFold.folds(in: turn(of: 1)).all.isEmpty)
        #expect(TranscriptFold.folds(in: turn(of: 2)).all.map { hides($0) } == [0])
        #expect(TranscriptFold.folds(in: turn(of: 3)).all.map { hides($0) } == [3])
        #expect(TranscriptFold.folds(in: turn(of: 9)).all.map { hides($0) } == [9])
    }

    @Test("a working gets its line long before it can fold")
    func theLineArrivesEarly() {
        #expect(TranscriptFold.leastWork < TranscriptFold.leastHidden)
        let two = [user(0), tool(1), tool(2)]
        #expect(TranscriptFold.folds(in: two).all.count == 1)
        #expect(TranscriptFold.folds(in: two).all.map { hides($0) } == [0])
        #expect(TranscriptFold.folds(in: [user(0), tool(1), prose(2)]).all.isEmpty)
    }

    @Test("a row whose result has not arrived is never hidden")
    func unsettledRowsAreNeverHidden() throws {
        let parallel = [user(0)] + (1..<7).map { tool($0, settled: false) }
        #expect(hides(try only(parallel)) == 0)

        let partly = [user(0)] + (1..<7).map { tool($0, settled: $0 < 5) }
        let work = try only(partly)
        #expect(work.ready == Set(1..<5))
        #expect(hides(work) == 4)
    }

    @Test("completed actions fold around a running command")
    func completedActionsSkipPendingRows() throws {
        let facts = [user(0), tool(1), tool(2), tool(3, settled: false), tool(4), tool(5), tool(6)]
        let work = try only(facts)
        #expect(TranscriptFold.hiddenIndices(work, revealed: [], drawn: everything) == [1, 2, 4, 5, 6])
    }

    @Test("a call that has only just been made folds before its result is back")
    func aFreshCallFolds() throws {
        let running = [user(0), tool(1), tool(2), tool(3), tool(4, settled: false, fresh: true)]
        let work = try only(running)
        #expect(TranscriptFold.hiddenIndices(work, revealed: [], drawn: everything) == [1, 2, 3, 4])

        let settled = [user(0), tool(1), tool(2), tool(3), tool(4, fresh: true)]
        #expect(try only(settled).ready == work.ready)

        let slow = [user(0), tool(1), tool(2), tool(3), tool(4, settled: false)]
        #expect(TranscriptFold.hiddenIndices(try only(slow), revealed: [], drawn: everything) == [1, 2, 3])
    }

    @Test("a fresh question nobody has answered is still never hidden")
    func aFreshAskIsNeverHidden() throws {
        var question = ask(4, decided: false)
        question.isFresh = true
        let work = try only([user(0), tool(1), tool(2), tool(3), question])
        #expect(TranscriptFold.hiddenIndices(work, revealed: [], drawn: everything) == [1, 2, 3])
    }

    @Test("a running first action does not block later completed commands")
    func runningFirstAction() throws {
        let facts = [user(10), tool(20, settled: false), quiet(30), tool(40), tool(50), tool(60)]
        let work = try only(facts)
        #expect(work.firstSeq == 20)
        #expect(TranscriptFold.hiddenIndices(work, revealed: [], drawn: everything) == [3, 4, 5])
        #expect(TranscriptFold.hiddenIndices(work, revealed: [50], drawn: everything).isEmpty)
    }

    @Test("out of order results grow the same fold without revealing completed actions")
    func resultsArriveOutOfOrder() throws {
        var facts = [user(0)] + (1...8).map { tool($0, settled: false) }
        var folds = TranscriptFold.folds(in: facts)
        var previous: Set<Int> = []
        for seq in [2, 4, 6, 8, 3, 7, 5, 1] {
            facts[seq].settled = true
            folds = TranscriptFold.folds(in: facts, extending: folds)
            let work = try #require(folds.all.first)
            let hidden = TranscriptFold.hiddenIndices(work, revealed: [], drawn: everything)
            #expect(folds.all.count == 1)
            #expect(work.firstSeq == 1)
            #expect(previous.isSubset(of: hidden))
            #expect(hidden.allSatisfy { facts[$0].settled })
            previous = hidden
        }
        #expect(previous == Set(1...8))
    }

    @Test("an error row stops the fold")
    func anErrorStopsTheFold() throws {
        let facts = [user(0), tool(1), tool(2), tool(3), tool(4), failure(5), tool(6)]
        #expect(hides(try only(facts)) == 4)
    }

    @Test("a question nobody has answered is never hidden")
    func anUndecidedAskIsNeverHidden() throws {
        let waiting = [user(0), tool(1), tool(2), tool(3), tool(4), ask(5, decided: false), tool(6)]
        let hidden = TranscriptFold.hiddenIndices(try only(waiting), revealed: [], drawn: everything)
        #expect(hidden == [1, 2, 3, 4, 6])
        let decided = [user(0), tool(1), tool(2), tool(3), tool(4), ask(5), tool(6)]
        #expect(hides(try only(decided)) == 6)
    }

    @Test("an opened row cuts the fold short rather than unfolding it")
    func anOpenedRowCapsThePrefix() throws {
        let work = try only([user(0)] + (1..<11).map { tool($0) })
        #expect(hides(work) == 10)
        #expect(hides(work, revealed: [5]) == 4)
        #expect(hides(work, revealed: [7, 5]) == 4)
    }

    @Test("a row something is aiming at is never hidden")
    func aSearchHitIsNeverHidden() throws {
        let work = try only([user(0)] + (1..<11).map { tool($0) })
        for seq in 1..<10 {
            #expect(hides(work, revealed: [seq]) <= seq - 1, "row \(seq) must still be drawn")
        }
        #expect(hides(work, revealed: [99]) == 10)
    }

    @Test("a failure counts as settled whatever the caller said")
    func aFailureIsSettled() throws {
        let facts = [user(0)] + (1..<7).map { tool($0, failed: $0 == 6, settled: $0 != 6) }
        let work = try only(facts)
        #expect(work.ready == Set(1..<7))
        #expect(hides(work) == 6)
    }

    @Test("a working that runs past the drawn window does not fold")
    func aWorkingOutsideTheWindowDoesNotFold() throws {
        let work = try only([user(0)] + (1..<7).map { tool($0) })
        #expect(TranscriptFold.hiddenIndices(work, revealed: [], drawn: 0..<7).count == 6)
        #expect(TranscriptFold.hiddenIndices(work, revealed: [], drawn: 0..<6).count == 0)
    }

    @Test("the window's start does not move what is hidden")
    func growingUpwardsTakesNothingOut() throws {
        let work = try only([user(0)] + (1..<7).map { tool($0) })
        #expect(TranscriptFold.hiddenIndices(work, revealed: [], drawn: 4..<20).count == 6)
        #expect(TranscriptFold.hiddenIndices(work, revealed: [], drawn: 0..<20).count == 6)
    }

    @Test("what a fold hides only ever grows")
    func monotone() {
        var facts = [user(0)]
        var folds = TranscriptFold.Folds.none
        var seen: [Int: Int] = [:]
        let revealed: Set<Int> = [7]

        for seq in 1..<12 {
            for at in facts.indices where facts[at].kind == .toolUse && !facts[at].settled {
                facts[at].settled = true
                facts[at].failed = facts[at].seq == 5
            }
            facts.append(tool(seq, settled: false))
            folds = TranscriptFold.folds(in: facts, extending: folds)
            for work in folds.all {
                let now = hides(work, revealed: revealed)
                #expect(now >= (seen[work.firstSeq] ?? 0), "row \(seq) unfolded \(work.firstSeq)")
                seen[work.firstSeq] = now
            }
        }
        for at in facts.indices where facts[at].kind == .toolUse { facts[at].settled = true }
        facts.append(prose(99))
        folds = TranscriptFold.folds(in: facts, extending: folds)
        for work in folds.all {
            #expect(hides(work, revealed: revealed) >= (seen[work.firstSeq] ?? 0))
        }
    }

    @Test("the expanded line names what is hidden and how many")
    func theLabel() {
        #expect(TranscriptFold.label(hiding: 14) == "14 actions")
        #expect(TranscriptFold.label(hiding: 11) == "11 actions")
    }

    @Test("the singular is there for whoever lowers the threshold")
    func theLabelHasASingular() {
        #expect(TranscriptFold.label(hiding: 1) == "1 action")
        #expect(TranscriptFold.label(hiding: 0) == "0 actions")
    }

    @Test("an open live turn folds back when new work reaches the live end")
    func refoldingLiveWork() throws {
        let live = try only([user(0)] + (1..<7).map { tool($0) })
        let laterLive = TranscriptFold.Work(
            span: 20..<24,
            rows: (20..<24).map { TranscriptFold.Row(index: $0, seq: $0) },
            ready: Set(20..<24),
            hasAnswer: false
        )
        let historical = TranscriptFold.Work(
            span: 10..<14,
            rows: (10..<14).map { TranscriptFold.Row(index: $0, seq: $0) },
            ready: Set(10..<14),
            hasAnswer: true
        )
        let folds = TranscriptFold.Folds(
            all: [historical, live, laterLive], scannedRows: 24, resumeIndex: 1
        )

        #expect(
            TranscriptFold.refoldedAtLiveEnd(
                [historical.firstSeq, live.firstSeq, laterLive.firstSeq], in: folds
            ) == [historical.firstSeq]
        )
        #expect(
            TranscriptFold.refoldedAtLiveEnd([historical.firstSeq], in: folds)
                == [historical.firstSeq]
        )
    }

    @Test("a row index finds the working it is in, and only that one")
    func lookupByIndex() {
        let facts = [user(0)] + (1..<5).map { tool($0) } + [prose(5), footer(6), user(7)]
            + (8..<12).map { tool($0) } + [prose(12)]
        let folds = TranscriptFold.folds(in: facts)
        #expect(folds.index(containing: 0) == nil)
        #expect(folds.fold(containing: 1)?.firstSeq == 1)
        #expect(folds.fold(containing: 4)?.firstSeq == 1)
        #expect(folds.index(containing: 5) == nil)
        #expect(folds.fold(containing: 8)?.firstSeq == 8)
        #expect(folds.fold(containing: 11)?.firstSeq == 8)
        #expect(folds.index(containing: 12) == nil)
        #expect(folds.index(containing: 99) == nil)
    }

    @Test("extending a scan gives the same answer as scanning from nothing")
    func extendingMatchesAFullScan() {
        var facts: [TranscriptFold.Fact] = []
        var extended = TranscriptFold.Folds.none
        let script: [TranscriptFold.Fact] = [
            user(0), tool(1), quiet(2), thinking(3), tool(4), prose(5), tool(6), notice(7),
            tool(8), tool(9), prose(10), footer(11),
            user(12), tool(13), tool(14, failed: true), ask(15, decided: false), tool(16), prose(17),
        ]
        for fact in script {
            facts.append(fact)
            extended = TranscriptFold.folds(in: facts, extending: extended)
            let whole = TranscriptFold.folds(in: facts)
            #expect(extended.all == whole.all, "after \(facts.count) rows")
            #expect(extended.resumeIndex == whole.resumeIndex, "after \(facts.count) rows")
            #expect(extended.scannedRows == whole.scannedRows, "after \(facts.count) rows")
        }
    }

    @Test("a shorter list than last time is scanned from the beginning")
    func aShorterListRescans() {
        let long = TranscriptFold.folds(in: [user(0)] + (1..<20).map { tool($0) })
        let short = [user(0), tool(1), tool(2), tool(3), prose(4)]
        let rescanned = TranscriptFold.folds(in: short, extending: long)
        #expect(rescanned.all == TranscriptFold.folds(in: short).all)
        #expect(rescanned.scannedRows == 5)
    }

    @Test("a rescan resumes past the last boundary")
    func resumeIsPastTheLastBoundary() {
        let facts = [user(0), tool(1), tool(2), prose(3), footer(4), user(5), tool(6), tool(7)]
        #expect(TranscriptFold.folds(in: facts).resumeIndex == 6)
    }
}
