import Testing
import Foundation
@testable import Core

@Suite("How a drawn transcript changed")
struct TranscriptEntryChangeTests {
    private func rows(_ seqs: [Int]) -> [TranscriptEntryID] {
        seqs.map { .row($0) }
    }

    private func drawn(
        _ seqs: [Int], pending: [String] = []
    ) -> [TranscriptEntryID] {
        [.setup] + rows(seqs) + [.sending, .streaming]
            + pending.map { .pending(DeliveryID($0)) } + [.bottomSpacing]
    }

    @Test("the same entries in the same order")
    func same() {
        #expect(TranscriptEntryChange.between(drawn([1, 2, 3]), drawn([1, 2, 3])) == .same)
    }

    @Test("two empty lists")
    func bothEmpty() {
        #expect(TranscriptEntryChange.between([TranscriptEntryID](), []) == .same)
    }

    @Test("a row landing at the live end is one insertion, not a rebuild")
    func aRowLandingIsNotARebuild() {
        let old = drawn(Array(0..<100))
        let new = drawn(Array(0..<101))
        #expect(TranscriptEntryChange.between(old, new) == .grew(head: 101..<102, tail: 0..<0))
    }

    @Test("history put in above the reader, under the setup log")
    func historyIsNotARebuild() {
        let old = drawn([5, 6, 7])
        let new = drawn([1, 2, 3, 4, 5, 6, 7])
        #expect(TranscriptEntryChange.between(old, new) == .grew(head: 1..<5, tail: 0..<0))
    }

    @Test("a queued message put on the end")
    func queuedMessage() {
        let old = drawn([1, 2], pending: ["a"])
        let new = drawn([1, 2], pending: ["a", "b"])
        #expect(TranscriptEntryChange.between(old, new) == .grew(head: 6..<7, tail: 0..<0))
    }

    @Test("both ends at once")
    func grewAtBothEnds() {
        let old = drawn([5, 6])
        let new = drawn([3, 4, 5, 6, 7])
        #expect(TranscriptEntryChange.between(old, new) == .grew(head: 1..<3, tail: 5..<6))
    }

    @Test("a list filled from nothing")
    func filled() {
        #expect(
            TranscriptEntryChange.between([], rows([1, 2, 3])) == .grew(head: 0..<3, tail: 0..<0)
        )
    }

    @Test("the window moved to the tail")
    func shrankAtTheHead() {
        let old = drawn([1, 2, 3, 4, 5])
        let new = drawn([4, 5])
        #expect(TranscriptEntryChange.between(old, new) == .shrank(head: 1..<4, tail: 0..<0))
    }

    @Test("a queued message sent")
    func shrankAtTheTail() {
        let old = drawn([1, 2, 3], pending: ["a", "b"])
        let new = drawn([1, 2, 3], pending: ["a"])
        #expect(TranscriptEntryChange.between(old, new) == .shrank(head: 7..<8, tail: 0..<0))
    }

    @Test("a whole list emptied")
    func emptied() {
        #expect(
            TranscriptEntryChange.between(rows([1, 2, 3]), []) == .shrank(head: 0..<3, tail: 0..<0)
        )
    }

    @Test("both ends taken away at once")
    func shrankAtBothEnds() {
        let old = drawn([3, 4, 5, 6, 7])
        let new = drawn([5, 6])
        #expect(TranscriptEntryChange.between(old, new) == .shrank(head: 1..<3, tail: 5..<6))
    }

    @Test("an unrelated list is a rebuild")
    func rebuilt() {
        #expect(TranscriptEntryChange.between(drawn([1, 2, 3]), drawn([9, 10, 11, 12])) == .rebuilt)
    }

    @Test("the same number of different rows is a rebuild")
    func sameLengthDifferentRows() {
        #expect(TranscriptEntryChange.between(rows([1, 2, 3]), rows([4, 5, 6])) == .rebuilt)
    }

    @Test("a repeated id does not fool the run search")
    func repeatedID() {
        let old = rows([2, 3, 4, 3])
        let new = rows([2, 9, 9, 3, 4, 3])
        #expect(TranscriptEntryChange.between(old, new) == .grew(head: 1..<3, tail: 0..<0))
    }

    @Test("only a change of shape moves anything under the reader")
    func movesRows() {
        #expect(!TranscriptEntryChange.same.movesRows)
        #expect(TranscriptEntryChange.grew(head: 1..<5, tail: 0..<0).movesRows)
        #expect(TranscriptEntryChange.shrank(head: 1..<4, tail: 0..<0).movesRows)
        #expect(TranscriptEntryChange.rebuilt.movesRows)
    }

    @Test("a growth's indices rebuild the new list from the old one")
    func indicesAreUsable() {
        let old = drawn([5, 6])
        let new = drawn([3, 4, 5, 6, 7])
        guard case .grew(let head, let tail) = TranscriptEntryChange.between(old, new) else {
            Issue.record("expected a growth")
            return
        }
        var rebuilt = old
        for index in head { rebuilt.insert(new[index], at: index) }
        for index in tail { rebuilt.insert(new[index], at: index) }
        #expect(rebuilt == new)
    }

    private func turn(_ entries: [TranscriptEntryID]) -> [TranscriptEntryID] {
        [.setup, .row(0)] + entries + [.sending, .streaming, .bottomSpacing]
    }

    @Test("a turn's line goes in while its working is far too short to fold")
    func theFoldLineArrives() {
        let old = turn(rows([1]))
        let new = turn([.fold(1)] + rows([1, 2]))
        #expect(TranscriptEntryChange.between(old, new) == .grew(head: 2..<3, tail: 4..<5))
    }

    @Test("a working reaching four rows folds by taking three out")
    func foldingIsOneRemoval() {
        let open = turn([.fold(1)] + rows([1, 2, 3, 4]))
        let folded = turn([.fold(1)] + rows([4]))
        #expect(TranscriptEntryChange.between(open, folded) == .shrank(head: 3..<6, tail: 0..<0))
    }

    @Test("a row landing in a folded turn, then the fold swallowing the one before it")
    func aRowLandsIntoAFoldedTurn() {
        let folded = turn([.fold(1)] + rows([4]))
        let landed = turn([.fold(1)] + rows([4, 5]))
        #expect(TranscriptEntryChange.between(folded, landed) == .grew(head: 4..<5, tail: 0..<0))
        let swallowed = turn([.fold(1)] + rows([5]))
        #expect(TranscriptEntryChange.between(landed, swallowed) == .shrank(head: 3..<4, tail: 0..<0))
    }

    @Test("the answer landing swallows the last row of the working")
    func theAnswerSwallowsTheRest() {
        let working = turn([.fold(1)] + rows([7]))
        let answered = turn([.fold(1)] + rows([7, 8]))
        #expect(TranscriptEntryChange.between(working, answered) == .grew(head: 4..<5, tail: 0..<0))
        let folded = turn([.fold(1)] + rows([8]))
        #expect(TranscriptEntryChange.between(answered, folded) == .shrank(head: 3..<4, tail: 0..<0))
    }

    @Test("opening a fold puts a turn's working back in one run")
    func unfoldingIsOneInsertion() {
        let folded = turn([.fold(1)] + rows([8]))
        let open = turn([.fold(1)] + rows([1, 2, 3, 4, 5, 6, 7, 8]))
        #expect(TranscriptEntryChange.between(folded, open) == .grew(head: 3..<10, tail: 0..<0))
        #expect(TranscriptEntryChange.between(open, folded) == .shrank(head: 3..<10, tail: 0..<0))
    }

    @Test("a row landing and a turn folding on one pass is a rebuild")
    func bothAtOnceIsARebuild() {
        let working = turn([.fold(1)] + rows([1, 2, 3, 4]))
        let landedAndFolded = turn([.fold(1)] + rows([5]))
        #expect(TranscriptEntryChange.between(working, landedAndFolded) == .rebuilt)
    }

    @Test("a delivery and a row are never the same entry")
    func kindsAreDistinct() {
        #expect(TranscriptEntryID.row(1).seq == 1)
        #expect(TranscriptEntryID.streaming.seq == nil)
        #expect(TranscriptEntryID.setup != TranscriptEntryID.streaming)
        #expect(TranscriptEntryID.pending(DeliveryID("1")) != TranscriptEntryID.row(1))
        #expect(TranscriptEntryID.fold(1) != TranscriptEntryID.row(1))
    }
}
