import Foundation
import Testing
@testable import Core

@Suite("A subagent is one row")
struct FoldingASubagentsRowsTests {
    private func task(_ seq: Int, id: String, settled: Bool = false) -> TranscriptFold.Fact {
        TranscriptFold.Fact(seq: seq, kind: .toolUse, settled: settled, toolUseID: id)
    }

    private func nested(
        _ seq: Int, under parent: String, failed: Bool = false, settled: Bool = true
    ) -> TranscriptFold.Fact {
        TranscriptFold.Fact(
            seq: seq, kind: .toolUse, failed: failed, settled: settled, parentToolUseID: parent
        )
    }

    private func nestedProse(_ seq: Int, under parent: String) -> TranscriptFold.Fact {
        TranscriptFold.Fact(seq: seq, kind: .assistantText, parentToolUseID: parent)
    }

    private func tool(_ seq: Int) -> TranscriptFold.Fact {
        TranscriptFold.Fact(seq: seq, kind: .toolUse)
    }

    private func user(_ seq: Int) -> TranscriptFold.Fact {
        TranscriptFold.Fact(seq: seq, kind: .user)
    }

    private func footer(_ seq: Int) -> TranscriptFold.Fact {
        TranscriptFold.Fact(seq: seq, kind: .result)
    }

    private let everything = 0..<1_000

    private func hides(_ work: TranscriptFold.Work) -> Int {
        TranscriptFold.hiddenIndices(work, revealed: [], drawn: everything).count
    }

    private func drawn(
        _ facts: [TranscriptFold.Fact],
        folds: TranscriptFold.Folds,
        revealed: Set<Int> = []
    ) -> [Int] {
        var out: [Int] = []
        for (index, fact) in facts.enumerated() {
            if let work = folds.fold(containing: index),
               TranscriptFold.hiddenIndices(work, revealed: revealed, drawn: everything).contains(index) {
                continue
            }
            if folds.absorbs(
                index: index, seq: fact.seq, parent: fact.parentToolUseID, revealed: revealed
            ) { continue }
            out.append(index)
        }
        return out
    }

    private func interleaved(steps: Int) -> [TranscriptFold.Fact] {
        var facts = [user(0), task(1, id: "a"), task(2, id: "b")]
        for step in 0..<steps {
            facts.append(nested(3 + step * 2, under: "a"))
            facts.append(nested(4 + step * 2, under: "b"))
        }
        return facts
    }

    @Test("two interleaved subagents each collapse to their call, with their own count")
    func interleavedSubagentsCollapse() {
        let facts = interleaved(steps: 6) + [nestedProse(15, under: "a"), nested(16, under: "a")]
        let folds = TranscriptFold.folds(in: facts)
        #expect(folds.actions(underCall: "a") == 7)
        #expect(folds.actions(underCall: "b") == 6)
        #expect(drawn(facts, folds: folds) == [0, 1, 2])
        #expect(folds.all.isEmpty)
    }

    @Test("a subagent's prose and thinking leave the list, and only activity is counted")
    func proseLeavesButIsNotCounted() {
        let facts = [
            user(0), task(1, id: "a"), nestedProse(2, under: "a"),
            TranscriptFold.Fact(seq: 3, kind: .thinking, parentToolUseID: "a"),
            nested(4, under: "a"),
            TranscriptFold.Fact(seq: 5, kind: .system, drawsNothing: true, parentToolUseID: "a"),
        ]
        let folds = TranscriptFold.folds(in: facts)
        #expect(folds.actions(underCall: "a") == 2)
        #expect(drawn(facts, folds: folds) == [0, 1])
    }

    @Test("a subagent's own subagent is counted into the call at the top")
    func grandchildrenCountUpwards() {
        let inner = TranscriptFold.Fact(seq: 3, kind: .toolUse, settled: false, toolUseID: "c", parentToolUseID: "a")
        let facts = [user(0), task(1, id: "a"), nested(2, under: "a"), inner]
            + (4..<7).map { nested($0, under: "c") }
        let folds = TranscriptFold.folds(in: facts)
        #expect(folds.actions(underCall: "a") == 5)
        #expect(folds.actions(underCall: "c") == nil)
        #expect(drawn(facts, folds: folds) == [0, 1])
    }

    @Test("a call that started nothing, or nothing yet, shows no count")
    func noCountWithoutWork() {
        let facts = [user(0), task(1, id: "a"), tool(2)]
        let folds = TranscriptFold.folds(in: facts)
        #expect(folds.actions(underCall: "a") == nil)
        #expect(folds.actions(underCall: nil) == nil)
    }

    @Test("a nested row whose call is nowhere is drawn, and folds among its own as before")
    func orphansStayDrawn() throws {
        let facts = [user(0)] + (1..<5).map { nested($0, under: "gone") }
        let folds = TranscriptFold.folds(in: facts)
        let work = try #require(folds.all.first)
        #expect(work.isNested)
        #expect(hides(work) == 4)
        #expect(!folds.absorbs(index: 1, seq: 1, parent: "gone", revealed: []))
    }

    @Test("the main agent's rows around interleaved subagents fold as one group")
    func mainWorkJoinsAcrossSubagents() throws {
        var facts = [user(0), task(1, id: "a"), task(2, id: "b")]
        var seq = 3
        for _ in 0..<4 {
            facts.append(nested(seq, under: "a"))
            facts.append(tool(seq + 1))
            facts.append(nested(seq + 2, under: "b"))
            seq += 3
        }
        let folds = TranscriptFold.folds(in: facts)
        #expect(folds.all.count == 1)
        let work = try #require(folds.all.first)
        #expect(work.rows.map(\.seq) == [4, 7, 10, 13])
        #expect(!work.isNested)
        #expect(hides(work) == 4)
        #expect(drawn(facts, folds: folds) == [0, 1, 2])
    }

    @Test("the call that started a subagent is not swallowed by the fold around it")
    func theCallStaysVisible() throws {
        let facts = [user(0), tool(1), tool(2), tool(3), task(4, id: "a", settled: true)]
            + [nestedProse(5, under: "a")] + (6..<10).map { nested($0, under: "a") }
            + (10..<13).map { tool($0) }
        let folds = TranscriptFold.folds(in: facts)
        #expect(folds.all.map(\.rows.count) == [3, 3])
        #expect(drawn(facts, folds: folds) == [0, 4])
        #expect(folds.actions(underCall: "a") == 4)
    }

    @Test("a permission question nobody has answered inside a subagent is drawn")
    func anUnansweredQuestionSurfaces() {
        let ask = TranscriptFold.Fact(seq: 4, kind: .permissionAsk, settled: false, parentToolUseID: "a")
        var facts = [user(0), task(1, id: "a"), nested(2, under: "a"), nested(3, under: "a"), ask]
        let folds = TranscriptFold.folds(in: facts)
        #expect(drawn(facts, folds: folds) == [0, 1, 4])

        facts[4].settled = true
        let answered = TranscriptFold.folds(in: facts)
        #expect(drawn(facts, folds: answered) == [0, 1])
    }

    @Test("an error, a question card and a row the reader was sent to are drawn")
    func theRestSurfaces() {
        let facts = [
            user(0), task(1, id: "a"), nested(2, under: "a"),
            TranscriptFold.Fact(seq: 3, kind: .error, parentToolUseID: "a"),
            TranscriptFold.Fact(seq: 4, kind: .permissionAsk, featured: true, parentToolUseID: "a"),
            nested(5, under: "a"),
            nested(6, under: "a", failed: true),
        ]
        let folds = TranscriptFold.folds(in: facts)
        #expect(drawn(facts, folds: folds) == [0, 1, 3, 4])
        #expect(drawn(facts, folds: folds, revealed: [5]) == [0, 1, 3, 4, 5])
    }

    @Test("a nested row the scan has not reached yet is never drawn")
    func unscannedRowsAreHeldBack() {
        let facts = [user(0), task(1, id: "a")]
        let stale = TranscriptFold.folds(in: facts)
        #expect(stale.absorbs(index: 2, seq: 2, parent: "a", revealed: []))
        #expect(!stale.absorbs(index: 2, seq: 2, parent: nil, revealed: []))
    }

    @Test("the count grows row by row while the drawn rows stay exactly as they were")
    func countsGrowWithoutMovingRows() {
        var facts = [user(0), tool(1), task(2, id: "a"), task(3, id: "b")]
        var folds = TranscriptFold.folds(in: facts)
        let before = drawn(facts, folds: folds)
        var lastCount = 0

        for step in 0..<20 {
            let parent = step.isMultiple(of: 3) ? "b" : "a"
            facts.append(nested(facts.count, under: parent, settled: false))
            #expect(drawn(facts, folds: folds) == before, "row \(facts.count - 1) was drawn")
            folds = TranscriptFold.folds(in: facts, extending: folds)
            let change = TranscriptEntryChange.between(before, drawn(facts, folds: folds))
            #expect(change == .same, "row \(facts.count - 1) moved the list")
            let count = folds.actions(underCall: "a") ?? 0
            #expect(count >= lastCount)
            lastCount = count
        }
        #expect(folds.actions(underCall: "a") == 13)
        #expect(folds.actions(underCall: "b") == 7)
    }

    @Test("children arriving after the turn ended still count on the call")
    func backgroundChildrenCount() {
        var facts = [user(0), task(1, id: "a", settled: true), footer(2), user(3)]
        var folds = TranscriptFold.folds(in: facts)
        #expect(folds.resumeIndex == 4)
        facts += [nested(4, under: "a"), tool(5), nested(6, under: "a")]
        folds = TranscriptFold.folds(in: facts, extending: folds)
        #expect(folds.actions(underCall: "a") == 2)
        #expect(folds == TranscriptFold.folds(in: facts))
    }

    @Test("extending a scan over nested rows matches a full scan")
    func extendingMatchesAFullScan() {
        var facts: [TranscriptFold.Fact] = []
        var extended = TranscriptFold.Folds.none
        let script: [TranscriptFold.Fact] = [
            user(0), tool(1), tool(2), task(3, id: "a"), nested(4, under: "a"),
            nested(5, under: "a"), nestedProse(6, under: "a"), tool(7), task(8, id: "b"),
            nested(9, under: "b"), nested(10, under: "a", failed: true),
            TranscriptFold.Fact(seq: 11, kind: .permissionAsk, settled: false, parentToolUseID: "b"),
            nested(12, under: "b"), tool(13), tool(14), footer(15), user(16),
            nested(17, under: "a"), nested(18, under: "gone"), tool(19), tool(20), tool(21),
            task(22, id: "c"), nested(23, under: "c"), nested(24, under: "b"),
        ]
        for fact in script {
            facts.append(fact)
            extended = TranscriptFold.folds(in: facts, extending: extended)
            let whole = TranscriptFold.folds(in: facts)
            #expect(extended == whole, "after \(facts.count) rows")
        }
        #expect(extended.actions(underCall: "a") == 4)
        #expect(extended.actions(underCall: "b") == 4)
        #expect(extended.actions(underCall: "c") == 1)
    }
}
