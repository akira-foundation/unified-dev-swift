import Foundation
import Testing
@testable import Core

@Suite("Transcript resume")
struct TranscriptResumeTests {
    private func state(
        expanded: Set<Int> = [],
        offset: Double = 1_200,
        anchorSeq: Int? = nil,
        anchorDelta: Double = 0,
        isAtLiveEnd: Bool = false,
        rowCount: Int = 400,
        drawn: TranscriptWindow = TranscriptWindow(start: 0, end: 400)
    ) -> TranscriptPaneState {
        TranscriptPaneState(
            expanded: expanded,
            offset: offset,
            anchorSeq: anchorSeq,
            anchorDelta: anchorDelta,
            isAtLiveEnd: isAtLiveEnd,
            rowCount: rowCount,
            drawn: drawn
        )
    }

    @Test("a pane that has never held this session draws the tail")
    func nothingRememberedDrawsTheTail() {
        let window = TranscriptResume.window(nil, tailStart: 3_920, rowCount: 4_000)
        #expect(window == TranscriptWindow(start: 3_920, end: 4_000))
    }

    @Test("a pane coming back to a session goes back to the window it was reading in")
    func aReturnGoesBackToItsWindow() {
        let remembered = state(drawn: TranscriptWindow(start: 3_600, end: 4_000))
        let window = TranscriptResume.window(remembered, tailStart: 3_920, rowCount: 4_000)
        #expect(window == TranscriptWindow(start: 3_600, end: 4_000))
    }

    @Test("a pane with nothing written down is arriving, and one with a memory is coming back")
    func resumingIsHavingBeenHereBefore() {
        #expect(TranscriptResume.isResuming(nil) == false)
        #expect(TranscriptResume.isResuming(state()))
    }

    @Test("a window with nothing in it is not restored, because it would draw a blank transcript")
    func anEmptyWindowIsNotAWindow() {
        let remembered = state(drawn: TranscriptWindow(start: 0, end: 0))
        let window = TranscriptResume.window(remembered, tailStart: 3_920, rowCount: 4_000)
        #expect(window == TranscriptWindow(start: 3_920, end: 4_000))
    }

    @Test("a window from a session that has since been read again is clamped to it")
    func aStaleWindowIsClamped() {
        let remembered = state(drawn: TranscriptWindow(start: 9_000, end: 9_400))
        let window = TranscriptResume.window(remembered, tailStart: 20, rowCount: 100)
        #expect(window == TranscriptWindow(start: 100, end: 100))
    }

    @Test("a reader is put back at the row they had at the top of the pane")
    func theAnchorRowIsRestored() {
        let placement = TranscriptResume.placement(for: state(anchorSeq: 120), rowCount: 400)
        #expect(placement == .row(seq: 120, delta: 0))
    }

    @Test("how far into that row they were comes back with it")
    func theAnchorDeltaIsRestored() {
        let placement = TranscriptResume.placement(
            for: state(anchorSeq: 120, anchorDelta: -1_840), rowCount: 400
        )
        #expect(placement == .row(seq: 120, delta: -1_840))
    }

    @Test("the row outranks the point, because the point is what answers without one")
    func theRowOutranksThePoint() {
        let placement = TranscriptResume.placement(
            for: state(offset: 9_000, anchorSeq: 120), rowCount: 400
        )
        #expect(placement == .row(seq: 120, delta: 0))
    }

    @Test("a reader who left at the end is put back at the end whatever row was on top")
    func liveEndOutranksTheRow() {
        let placement = TranscriptResume.placement(
            for: state(anchorSeq: 120, isAtLiveEnd: true), rowCount: 400
        )
        #expect(placement == .liveEnd)
    }

    @Test("a pane that could name no row falls back to the point it was at")
    func noRowFallsBackToThePoint() {
        let placement = TranscriptResume.placement(for: state(offset: 1_200), rowCount: 400)
        #expect(placement == .offset(1_200))
    }

    @Test("a place measured in one session cannot land under another session's key")
    func aWriteBelongsToTheSessionItWasMeasuredIn() {
        #expect(!TranscriptResume.mayRemember(
            arrived: SessionID("being-left"),
            writingTo: SessionID("arriving"),
            drawnRows: 400,
            paneHeight: 800
        ))
    }

    @Test("the session being left is written down on the way out")
    func theSessionBeingLeftIsWritten() {
        #expect(TranscriptResume.mayRemember(
            arrived: SessionID("being-left"),
            writingTo: SessionID("being-left"),
            drawnRows: 400,
            paneHeight: 800
        ))
    }

    @Test("a pane that has drawn nothing, or has never been laid out, writes nothing")
    func nothingIsWrittenBeforeThereIsSomethingToWrite() {
        let session = SessionID("one")
        #expect(!TranscriptResume.mayRemember(
            arrived: session, writingTo: session, drawnRows: 0, paneHeight: 800
        ))
        #expect(!TranscriptResume.mayRemember(
            arrived: session, writingTo: session, drawnRows: 400, paneHeight: 0
        ))
        #expect(!TranscriptResume.mayRemember(
            arrived: nil, writingTo: session, drawnRows: 400, paneHeight: 800
        ))
        #expect(!TranscriptResume.mayRemember(
            arrived: session, writingTo: nil, drawnRows: 400, paneHeight: 800
        ))
    }

    @Test("a pane that has never held this session opens the way it always did")
    func nothingRemembered() {
        let placement = TranscriptResume.placement(
            for: nil, rowCount: 400
        )
        #expect(placement == .first)
    }

    @Test("a session with no rows opens the way it always did")
    func emptySession() {
        #expect(TranscriptResume.placement(for: state(), rowCount: 0) == .first)
    }

    @Test("a reader who left at the end is put back at the end, not at the offset")
    func liveEndOutranksTheOffset() {
        let placement = TranscriptResume.placement(
            for: state(offset: 9_000, isAtLiveEnd: true), rowCount: 400
        )
        #expect(placement == .liveEnd)
    }

    @Test("the end still means the end after the session has grown")
    func liveEndAfterGrowth() {
        let placement = TranscriptResume.placement(
            for: state(offset: 9_000, isAtLiveEnd: true, rowCount: 400),
            rowCount: 6_000
        )
        #expect(placement == .liveEnd)
    }

    @Test("a reader who left part way up is put back there")
    func offsetIsRestored() {
        let placement = TranscriptResume.placement(
            for: state(offset: 1_200), rowCount: 400
        )
        #expect(placement == .offset(1_200))
    }

    @Test("a session that has grown under a scrolled reader keeps their offset")
    func growthDoesNotMoveAReader() {
        let placement = TranscriptResume.placement(
            for: state(offset: 1_200, rowCount: 400), rowCount: 900
        )
        #expect(placement == .offset(1_200))
    }

    @Test("a session with fewer rows than it had is not the one that offset was measured in")
    func shrunkSessionIsNotResumed() {
        let placement = TranscriptResume.placement(
            for: state(rowCount: 400), rowCount: 12
        )
        #expect(placement == .first)
    }

    @Test("the top of a conversation is a place, and is restored")
    func theTopIsAPlace() {
        #expect(TranscriptResume.placement(for: state(offset: 0), rowCount: 400) == .offset(0))
    }
}
