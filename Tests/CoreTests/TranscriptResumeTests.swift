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
        let window = TranscriptResume.window(nil, tailStart: 3_920, seqs: 0..<4_000)
        #expect(window == TranscriptWindow(start: 3_920, end: 4_000))
    }

    @Test("a pane coming back to a session goes back to the window it was reading in")
    func aReturnGoesBackToItsWindow() {
        let remembered = state(drawn: TranscriptWindow(start: 3_600, end: 4_000))
        let window = TranscriptResume.window(remembered, tailStart: 3_920, seqs: 0..<4_000)
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
        let window = TranscriptResume.window(remembered, tailStart: 3_920, seqs: 0..<4_000)
        #expect(window == TranscriptWindow(start: 3_920, end: 4_000))
    }

    @Test("a window from a session that has since been read again is clamped to it")
    func aStaleWindowIsClamped() {
        let remembered = state(drawn: TranscriptWindow(start: 9_000, end: 9_400))
        let window = TranscriptResume.window(remembered, tailStart: 20, seqs: 0..<100)
        #expect(window == TranscriptWindow(start: 100, end: 100))
    }

    @Test("a reader is put back at the row they had at the top of the pane")
    func theAnchorRowIsRestored() {
        let placement = TranscriptResume.placement(for: state(anchorSeq: 120), seqs: 0..<400)
        #expect(placement == .row(seq: 120, delta: 0))
    }

    @Test("how far into that row they were comes back with it")
    func theAnchorDeltaIsRestored() {
        let placement = TranscriptResume.placement(
            for: state(anchorSeq: 120, anchorDelta: -1_840), seqs: 0..<400
        )
        #expect(placement == .row(seq: 120, delta: -1_840))
    }

    @Test("the row outranks the point, because the point is what answers without one")
    func theRowOutranksThePoint() {
        let placement = TranscriptResume.placement(
            for: state(offset: 9_000, anchorSeq: 120), seqs: 0..<400
        )
        #expect(placement == .row(seq: 120, delta: 0))
    }

    @Test("a reader who left at the end is put back at the end whatever row was on top")
    func liveEndOutranksTheRow() {
        let placement = TranscriptResume.placement(
            for: state(anchorSeq: 120, isAtLiveEnd: true), seqs: 0..<400
        )
        #expect(placement == .liveEnd)
    }

    @Test("a pane that could name no row falls back to the point it was at")
    func noRowFallsBackToThePoint() {
        let placement = TranscriptResume.placement(for: state(offset: 1_200), seqs: 0..<400)
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
            for: nil, seqs: 0..<400
        )
        #expect(placement == .first)
    }

    @Test("a session with no rows opens the way it always did")
    func emptySession() {
        #expect(TranscriptResume.placement(for: state(), seqs: 0..<0) == .first)
    }

    @Test("a reader who left at the end is put back at the end, not at the offset")
    func liveEndOutranksTheOffset() {
        let placement = TranscriptResume.placement(
            for: state(offset: 9_000, isAtLiveEnd: true), seqs: 0..<400
        )
        #expect(placement == .liveEnd)
    }

    @Test("a reader who left at the end with no row to name returns to the end")
    func liveEndAfterGrowth() {
        let placement = TranscriptResume.placement(
            for: state(offset: 9_000, isAtLiveEnd: true, rowCount: 400), seqs: 0..<6_000
        )
        #expect(placement == .liveEnd)
    }

    @Test("a reader who left part way up is put back there")
    func offsetIsRestored() {
        let placement = TranscriptResume.placement(
            for: state(offset: 1_200), seqs: 0..<400
        )
        #expect(placement == .offset(1_200))
    }

    @Test("a session that has grown under a scrolled reader keeps their offset")
    func growthDoesNotMoveAReader() {
        let placement = TranscriptResume.placement(
            for: state(offset: 1_200, rowCount: 400), seqs: 0..<900
        )
        #expect(placement == .offset(1_200))
    }

    @Test("a session with fewer rows than it had is not the one that offset was measured in")
    func shrunkSessionIsNotResumed() {
        let placement = TranscriptResume.placement(
            for: state(rowCount: 400), seqs: 0..<12
        )
        #expect(placement == .first)
    }

    @Test("the top of a conversation is a place, and is restored")
    func theTopIsAPlace() {
        #expect(TranscriptResume.placement(for: state(offset: 0), seqs: 0..<400) == .offset(0))
    }

    @Test("a reader who left at the end returns to the row they saw once the session has grown")
    func theEndIsNotChasedAfterGrowth() {
        let placement = TranscriptResume.placement(
            for: state(anchorSeq: 390, anchorDelta: 12, isAtLiveEnd: true, rowCount: 400),
            seqs: 0..<900
        )
        #expect(placement == .row(seq: 390, delta: 12))
    }

    @Test("a reader who left at the end and missed nothing is at the end")
    func theEndHoldsWithNothingNew() {
        let placement = TranscriptResume.placement(
            for: state(anchorSeq: 390, anchorDelta: 12, isAtLiveEnd: true, rowCount: 400),
            seqs: 0..<400
        )
        #expect(placement == .liveEnd)
    }

    @Test("a row that has gone gives way to the next one, without its old depth")
    func aGoneRowLandsOnTheNext() {
        let placement = TranscriptResume.placement(
            for: state(anchorSeq: 11, anchorDelta: 40, rowCount: 400),
            seqs: [10, 20, 30]
        )
        #expect(placement == .row(seq: 20, delta: 0))
    }

    @Test("a remembered row past every row that is left lands at the end")
    func aRowPastTheEndLandsAtTheEnd() {
        let placement = TranscriptResume.placement(
            for: state(anchorSeq: 99, rowCount: 400), seqs: [10, 20, 30]
        )
        #expect(placement == .liveEnd)
    }

    @Test("rows unread since the last open do not pull the window off the remembered place")
    func anUnreadRowDoesNotOutrankTheMemory() {
        let seq = TranscriptResume.mustReach(
            target: nil, remembered: state(anchorSeq: 3_900), firstUnread: 1_000
        )
        #expect(seq == nil)
    }

    @Test("a session never read here reaches for its first unread row")
    func unreadDecidesWithNoMemory() {
        #expect(TranscriptResume.mustReach(target: nil, remembered: nil, firstUnread: 1_000) == 1_000)
    }

    @Test("a search or notification target outranks both")
    func theTargetOutranksTheMemory() {
        let seq = TranscriptResume.mustReach(
            target: 7, remembered: state(anchorSeq: 3_900), firstUnread: 1_000
        )
        #expect(seq == 7)
    }

    @Test("a window that does not hold the remembered row is moved to it")
    func theWindowReachesTheRow() {
        let remembered = state(
            anchorSeq: 1_000, drawn: TranscriptWindow(start: 3_600, end: 4_000)
        )
        let window = TranscriptResume.window(remembered, tailStart: 3_920, seqs: 0..<4_000)
        #expect(window == TranscriptWindow(start: 920, end: 1_400))
    }

    @Test("a place read back from disk has no window, and draws around its row")
    func aPlaceWithNoWindowDrawsAroundItsRow() {
        let remembered = state(
            anchorSeq: 1_000, rowCount: 4_000, drawn: TranscriptWindow(start: 0, end: 0)
        )
        let window = TranscriptResume.window(remembered, tailStart: 3_920, seqs: 0..<4_000)
        #expect(window == TranscriptWindow(start: 920, end: 1_400))
    }

    @Test("the window of a reader who left at the end reaches below, so new rows do not drag them")
    func grownSessionDrawsBelowTheEnd() {
        let remembered = state(
            anchorSeq: 3_990, isAtLiveEnd: true, rowCount: 4_000,
            drawn: TranscriptWindow(start: 3_600, end: 4_000)
        )
        let window = TranscriptResume.window(remembered, tailStart: 3_920, seqs: 0..<4_002)
        #expect(window == TranscriptWindow(start: 3_600, end: 4_002))
    }

    @Test("a place is what is kept on disk, and comes back as the same place")
    func thePlaceRoundTrips() throws {
        let left = state(anchorSeq: 42, anchorDelta: 8, isAtLiveEnd: true, rowCount: 90)
        let place = try #require(left.place)
        let back = TranscriptPaneState(place: place)
        #expect(back.anchorSeq == 42)
        #expect(back.anchorDelta == 8)
        #expect(back.isAtLiveEnd)
        #expect(back.rowCount == 90)
        #expect(back.drawn.count == 0)
    }

    @Test("a pane that could name no row has no place to keep")
    func noRowIsNoPlace() {
        #expect(state(anchorSeq: nil).place == nil)
    }

    @Test("a pane already showing another session does not note what it sees for the one it left")
    func aSwitchInProgressNotesNothing() {
        let left = SessionID("left")
        let next = SessionID("next")
        #expect(TranscriptResume.mayNoteSeen(arrived: left, drawnFor: left, showing: next) == false)
        #expect(TranscriptResume.mayNoteSeen(arrived: next, drawnFor: left, showing: next) == false)
        #expect(TranscriptResume.mayNoteSeen(arrived: next, drawnFor: next, showing: next))
    }

    @Test("a reader who left at the end and is read back from disk draws the end of the session")
    func theEndReadBackDrawsTheEnd() {
        let remembered = state(
            anchorSeq: 1_000, isAtLiveEnd: true, rowCount: 4_000,
            drawn: TranscriptWindow(start: 0, end: 0)
        )
        let window = TranscriptResume.window(remembered, tailStart: 3_920, seqs: 0..<4_000)
        #expect(window == TranscriptWindow(start: 3_600, end: 4_000))
    }

    @Test("a search target outranks the remembered place")
    func theTargetOutranksThePlace() {
        let placement = TranscriptResume.placement(
            for: state(anchorSeq: 390, isAtLiveEnd: true), seqs: 0..<400, target: 12
        )
        #expect(placement == .target(seq: 12))
    }

    @Test("a remembered row past every row that is left draws the end it will land on")
    func aRowPastTheEndDrawsTheEnd() {
        let remembered = state(
            anchorSeq: 9_000, drawn: TranscriptWindow(start: 0, end: 50)
        )
        let window = TranscriptResume.window(remembered, tailStart: 3_920, seqs: 0..<4_000)
        #expect(window == TranscriptWindow(start: 3_600, end: 4_000))
    }
}
