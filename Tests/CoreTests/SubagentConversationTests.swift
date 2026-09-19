import Foundation
import Testing
@testable import Core

@Suite("Laying out a subagent's conversation")
struct SubagentConversationTests {
    private static let parent = "toolu_task"

    private func tool(_ seq: Int, settled: Bool = true) -> TranscriptFold.Fact {
        TranscriptFold.Fact(
            seq: seq, kind: .toolUse, settled: settled, toolUseID: "call\(seq)",
            parentToolUseID: Self.parent
        )
    }

    private func thinking(_ seq: Int) -> TranscriptFold.Fact {
        TranscriptFold.Fact(seq: seq, kind: .thinking, parentToolUseID: Self.parent)
    }

    private func prose(_ seq: Int) -> TranscriptFold.Fact {
        TranscriptFold.Fact(seq: seq, kind: .assistantText, parentToolUseID: Self.parent)
    }

    @Test func aRunOfWorkFoldsIntoOneLineAboveTheAnswer() {
        let facts = [thinking(-1), tool(-2), tool(-3), tool(-4), tool(-5), prose(-6)]
        let entries = SubagentConversation.entries(facts: facts, unfolded: [], revealed: [])
        #expect(entries == [
            .fold(firstSeq: -1, hiding: 5, showsMore: false, isFolded: true),
            .row(index: 5, seq: -6),
        ])
    }

    @Test func proseDividesTheWorkIntoSeparateFolds() {
        let facts = [tool(1), tool(2), tool(3), prose(4), tool(5), tool(6), tool(7), prose(8)]
        let entries = SubagentConversation.entries(facts: facts, unfolded: [], revealed: [])
        #expect(entries.map(\.id) == [.fold(1), .row(4), .fold(5), .row(8)])
    }

    @Test func theParentIdOnEveryRowDoesNotNestOrSplitAnything() {
        let nested = [tool(1), tool(2), tool(3)]
        let flat = nested.map { fact in
            var own = fact
            own.parentToolUseID = nil
            return own
        }
        let fromNested = SubagentConversation.entries(facts: nested, unfolded: [], revealed: [])
        let fromFlat = SubagentConversation.entries(facts: flat, unfolded: [], revealed: [])
        #expect(fromNested == fromFlat)
        #expect(fromNested == [.fold(firstSeq: 1, hiding: 3, showsMore: false, isFolded: true)])
    }

    @Test func anOpenedRunDrawsEveryRowUnderItsLine() {
        let facts = [tool(1), tool(2), tool(3), prose(4)]
        let entries = SubagentConversation.entries(facts: facts, unfolded: [1], revealed: [])
        #expect(entries == [
            .fold(firstSeq: 1, hiding: 3, showsMore: false, isFolded: false),
            .row(index: 0, seq: 1), .row(index: 1, seq: 2), .row(index: 2, seq: 3),
            .row(index: 3, seq: 4),
        ])
    }

    @Test func aCallStillRunningStandsBelowItsFold() {
        let facts = [tool(1), tool(2), tool(3), tool(4, settled: false)]
        let entries = SubagentConversation.entries(facts: facts, unfolded: [], revealed: [])
        #expect(entries == [
            .fold(firstSeq: 1, hiding: 3, showsMore: true, isFolded: true),
            .row(index: 3, seq: 4),
        ])
    }

    @Test func tooShortARunIsDrawnAsItsRows() {
        let facts = [tool(1), tool(2), prose(3)]
        let entries = SubagentConversation.entries(facts: facts, unfolded: [], revealed: [])
        #expect(entries.map(\.id) == [.row(1), .row(2), .row(3)])
    }

    @Test func anOpenedRowCapsWhatItsRunHides() {
        let facts = [tool(1), tool(2), tool(3), tool(4), tool(5), tool(6)]
        let entries = SubagentConversation.entries(facts: facts, unfolded: [], revealed: [4])
        #expect(entries.map(\.id) == [.fold(1), .row(4), .row(5), .row(6)])
    }

    @Test func aFoldKeepsItsIdentityWhenEarlierRowsAreDropped() {
        let before = [prose(-9), tool(-1), tool(-2), tool(-3), prose(-4)]
        let after = Array(before.dropFirst())
        let opened = SubagentConversation.entries(facts: before, unfolded: [-1], revealed: [])
        let reread = SubagentConversation.entries(facts: after, unfolded: [-1], revealed: [])
        #expect(opened.first(where: { $0.id == .fold(-1) }) == reread.first)
        #expect(reread.first == .fold(firstSeq: -1, hiding: 3, showsMore: false, isFolded: false))
    }
}
