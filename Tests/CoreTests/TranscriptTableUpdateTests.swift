import Testing
import Foundation
@testable import Core

@Suite("What a transcript table is told about a pass")
struct TranscriptTableUpdateTests {
    @Test("a shrink with a moved environment is a reload and no removal")
    func shrinkWithAMovedEnvironmentStagesNothing() {
        let change = TranscriptEntryChange.shrank(head: 0..<40, tail: 0..<0)
        #expect(
            TranscriptTableUpdate.plan(change: change, environmentMoved: true) == .reload
        )
    }

    @Test("a growth with a moved environment is a reload and no insertion")
    func growthWithAMovedEnvironmentStagesNothing() {
        let change = TranscriptEntryChange.grew(head: 0..<400, tail: 0..<0)
        #expect(
            TranscriptTableUpdate.plan(change: change, environmentMoved: true) == .reload
        )
    }

    @Test("a moved environment never stages rows, whatever the change was")
    func aMovedEnvironmentNeverStagesRows() {
        let changes: [TranscriptEntryChange] = [
            .same,
            .grew(head: 0..<3, tail: 0..<0),
            .grew(head: 0..<0, tail: 7..<9),
            .shrank(head: 0..<3, tail: 0..<0),
            .shrank(head: 0..<0, tail: 7..<9),
            .rebuilt,
        ]
        for change in changes {
            #expect(TranscriptTableUpdate.plan(change: change, environmentMoved: true) == .reload)
        }
    }

    @Test("a row arriving is an insertion")
    func aRowArrivingIsAnInsertion() {
        let change = TranscriptEntryChange.grew(head: 0..<0, tail: 12..<13)
        #expect(
            TranscriptTableUpdate.plan(change: change, environmentMoved: false)
                == .rows(.grew(head: 0..<0, tail: 12..<13))
        )
    }

    @Test("rows leaving are a removal")
    func rowsLeavingAreARemoval() {
        let change = TranscriptEntryChange.shrank(head: 4..<9, tail: 0..<0)
        #expect(
            TranscriptTableUpdate.plan(change: change, environmentMoved: false)
                == .rows(.shrank(head: 4..<9, tail: 0..<0))
        )
    }

    @Test("the same list is no row edit at all")
    func theSameListIsNoEdit() {
        #expect(TranscriptTableUpdate.plan(change: .same, environmentMoved: false) == .nothing)
    }

    @Test("a rebuilt list is a reload")
    func aRebuiltListIsAReload() {
        #expect(TranscriptTableUpdate.plan(change: .rebuilt, environmentMoved: false) == .reload)
    }
}
