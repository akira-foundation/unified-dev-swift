import Foundation
import Testing
@testable import Core

@Suite("Folding an errored action")
struct FoldingAnErroredActionTests {
    private func tool(_ seq: Int, failed: Bool = false, settled: Bool = true) -> TranscriptFold.Fact {
        TranscriptFold.Fact(seq: seq, kind: .toolUse, failed: failed, settled: settled)
    }

    private func media(_ seq: Int) -> TranscriptFold.Fact {
        TranscriptFold.Fact(seq: seq, kind: .toolUse, featured: true)
    }

    private func agentExit(_ seq: Int) -> TranscriptFold.Fact {
        TranscriptFold.Fact(seq: seq, kind: .error)
    }

    private func prose(_ seq: Int) -> TranscriptFold.Fact {
        TranscriptFold.Fact(seq: seq, kind: .assistantText)
    }

    private func user(_ seq: Int) -> TranscriptFold.Fact {
        TranscriptFold.Fact(seq: seq, kind: .user)
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

    @Test("a failed call in the middle of a run folds with the rest of it")
    func aFailureInTheMiddleFolds() throws {
        let facts = [user(0)] + (1..<10).map { tool($0, failed: $0 == 5) }
        let work = try only(facts)
        #expect(work.rows.count == 9)
        #expect(hides(work) == 9)
        let folds = TranscriptFold.folds(in: facts)
        #expect(folds.fold(containing: 5)?.firstSeq == 1)
    }

    @Test("the reported transcript folds into a single group")
    func theReportedTranscript() throws {
        var facts = [user(0)]
        facts += (1...7).map { tool($0) }
        facts.append(tool(8, failed: true))
        facts += (9...50).map { tool($0) }
        facts.append(tool(51, failed: true))
        facts += (52...139).map { tool($0) }
        let work = try only(facts)
        #expect(work.rows.count == 139)
        #expect(hides(work) == 139)
    }

    @Test("a run that opens with a failed call folds from its first row")
    func aFailureAtTheStartFolds() throws {
        let work = try only([user(0), tool(1, failed: true), tool(2), tool(3), tool(4)])
        #expect(work.rows.first?.seq == 1)
        #expect(work.rows.count == 4)
        #expect(hides(work) == 4)
    }

    @Test("a run that ends on a failed call folds through it")
    func aFailureAtTheEndFolds() throws {
        let work = try only([user(0), tool(1), tool(2), tool(3), tool(4, failed: true)])
        #expect(work.rows.count == 4)
        #expect(hides(work) == 4)
    }

    @Test("consecutive failures do not start a new group")
    func consecutiveFailuresFoldTogether() throws {
        let facts = [user(0)]
            + (1..<41).map { tool($0) }
            + [tool(41, failed: true), tool(42, failed: true)]
            + (43..<63).map { tool($0) }
        let work = try only(facts)
        #expect(work.rows.count == 62)
        #expect(hides(work) == 62)
    }

    @Test("a refused call folds like any other settled row")
    func aRefusalFolds() throws {
        let work = try only([user(0)] + (1..<8).map { tool($0, failed: $0 == 3) })
        #expect(hides(work) == 7)
    }

    @Test("a hidden call coming back a failure does not unfold anything")
    func aLateFailureDoesNotUnfold() {
        var facts = [user(0)]
        var folds = TranscriptFold.Folds.none
        var seen: [Int: Int] = [:]

        for seq in 1..<12 {
            for at in facts.indices where facts[at].kind == .toolUse && !facts[at].settled {
                facts[at].settled = true
                facts[at].failed = facts[at].seq == 5 || facts[at].seq == 9
            }
            facts.append(tool(seq, settled: false))
            folds = TranscriptFold.folds(in: facts, extending: folds)
            for work in folds.all {
                let now = hides(work)
                #expect(now >= (seen[work.firstSeq] ?? 0), "row \(seq) unfolded \(work.firstSeq)")
                seen[work.firstSeq] = now
            }
        }
        #expect(folds.all.count == 1)
        #expect(folds.all.first?.rows.count == 11)
    }

    @Test("an errored row a reader is taken to is still not hidden")
    func aFailureSomethingAimsAtIsDrawn() throws {
        let work = try only([user(0)] + (1..<10).map { tool($0, failed: $0 == 5) })
        #expect(hides(work) == 9)
        #expect(hides(work, revealed: [5]) == 4)
    }

    @Test("the line stays a plain count")
    func theLineIsAPlainCount() {
        #expect(TranscriptFold.label(hiding: 139) == "139 actions")
    }

    @Test("an agent error row still separates two groups")
    func anAgentErrorStillSeparates() {
        let facts = [user(0)] + (1..<5).map { tool($0) } + [agentExit(5)]
            + (6..<10).map { tool($0) }
        let folds = TranscriptFold.folds(in: facts)
        #expect(folds.all.count == 2)
        #expect(folds.all.map(\.rows.count) == [4, 4])
        #expect(folds.index(containing: 5) == nil)
    }

    @Test("a featured row still separates two groups")
    func featuredContentStillSeparates() {
        let facts = [user(0)] + (1..<5).map { tool($0) } + [media(5)] + (6..<10).map { tool($0) }
        let folds = TranscriptFold.folds(in: facts)
        #expect(folds.all.count == 2)
        #expect(folds.all.map(\.rows.count) == [4, 4])
        #expect(folds.index(containing: 5) == nil)
    }

    @Test("prose still closes a group that holds a failure")
    func proseStillClosesAGroup() {
        let facts = [user(0)] + (1..<5).map { tool($0, failed: $0 == 2) } + [prose(5)]
            + (6..<10).map { tool($0) }
        let folds = TranscriptFold.folds(in: facts)
        #expect(folds.all.count == 2)
        #expect(folds.all.map(\.rows.count) == [4, 4])
        #expect(folds.all.map(\.hasAnswer) == [true, false])
    }
}
