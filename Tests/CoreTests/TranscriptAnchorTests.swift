import Testing
import Foundation
@testable import Core

@Suite("Keeping a transcript reader still")
struct TranscriptAnchorTests {
    @Test("rows put in above the reader do not move the reader")
    func historyAboveTheReaderMovesNothing() {
        let delta = TranscriptAnchor.delta(rowTop: 8_000, viewportTop: 8_040)
        #expect(delta == -40)
        let restored = TranscriptAnchor.offset(rowTop: 20_000, delta: delta)
        #expect(restored == 20_040)
    }

    @Test("a row exactly at the top of the pane comes back exactly there")
    func flushWithTheTop() {
        let delta = TranscriptAnchor.delta(rowTop: 8_000, viewportTop: 8_000)
        #expect(TranscriptAnchor.offset(rowTop: 500, delta: delta) == 500)
    }

    @Test("rows taken from above the reader do not move the reader either")
    func historyRemovedMovesNothing() {
        let delta = TranscriptAnchor.delta(rowTop: 20_000, viewportTop: 20_120)
        #expect(TranscriptAnchor.offset(rowTop: 300, delta: delta) == 420)
    }

    @Test("the round trip is the identity whatever the row moved by")
    func roundTrip() {
        for move in [-9_000.0, -1, 0, 1, 12_345] {
            let rowTop = 4_000.0
            let delta = TranscriptAnchor.delta(rowTop: rowTop, viewportTop: 4_017)
            #expect(TranscriptAnchor.offset(rowTop: rowTop + move, delta: delta) == 4_017 + move)
        }
    }

    @Test("the end of the content is the content less the pane")
    func end() {
        #expect(TranscriptAnchor.end(contentHeight: 20_000, viewportHeight: 800) == 19_200)
    }

    @Test("content that fits has nowhere to go")
    func endOfShortContent() {
        #expect(TranscriptAnchor.end(contentHeight: 300, viewportHeight: 800) == 0)
        #expect(TranscriptAnchor.end(contentHeight: 300, viewportHeight: 0) == 300)
        #expect(TranscriptAnchor.end(contentHeight: 0, viewportHeight: 0) == 0)
    }

    @Test("a wanted offset is brought inside the range")
    func clamps() {
        #expect(TranscriptAnchor.clamped(-500, contentHeight: 20_000, viewportHeight: 800) == 0)
        #expect(
            TranscriptAnchor.clamped(1_000_000, contentHeight: 20_000, viewportHeight: 800)
                == 19_200
        )
        #expect(TranscriptAnchor.clamped(5_000, contentHeight: 20_000, viewportHeight: 800) == 5_000)
    }

    @Test("asking for past the end is asking for the end")
    func pastTheEndIsTheEnd() {
        let end = TranscriptAnchor.end(contentHeight: 20_000, viewportHeight: 800)
        #expect(
            TranscriptAnchor.clamped(20_000, contentHeight: 20_000, viewportHeight: 800) == end
        )
    }

    @Test("a row at the top of the pane")
    func rowAtTheTop() {
        let y = TranscriptAnchor.offset(
            rowTop: 5_000, rowHeight: 120, viewportHeight: 800, anchor: 0
        )
        #expect(y == 5_000)
    }

    @Test("a row centred in the pane")
    func rowCentred() {
        let y = TranscriptAnchor.offset(
            rowTop: 5_000, rowHeight: 120, viewportHeight: 800, anchor: 0.5
        )
        #expect(y == 5_000 + 60 - 400)
    }

    @Test("a row against the bottom of the pane")
    func rowAtTheBottom() {
        let y = TranscriptAnchor.offset(
            rowTop: 5_000, rowHeight: 120, viewportHeight: 800, anchor: 1
        )
        #expect(y == 5_120 - 800)
    }

    @Test("a row near either end resolves outside the range and is clamped by the caller")
    func rowNearTheEdges() {
        let high = TranscriptAnchor.offset(
            rowTop: 10, rowHeight: 40, viewportHeight: 800, anchor: 0.5
        )
        #expect(high < 0)
        #expect(TranscriptAnchor.clamped(high, contentHeight: 20_000, viewportHeight: 800) == 0)
    }

    @Test("nearly at the end is not at the end")
    func nearlyIsNotAtIt() {
        #expect(TranscriptAnchor.isAtEnd(offset: 19_200, contentHeight: 20_000, viewportHeight: 800))
        #expect(!TranscriptAnchor.isAtEnd(offset: 19_110, contentHeight: 20_000, viewportHeight: 800))
        #expect(
            ScrollEnd.isAtEnd(contentHeight: 20_000, viewportHeight: 800, offset: 19_110)
        )
    }

    @Test("a fraction of a point still counts as the end")
    func aFractionIsStillTheEnd() {
        #expect(
            TranscriptAnchor.isAtEnd(offset: 19_199.4, contentHeight: 20_000, viewportHeight: 800)
        )
    }

    @Test("past the end counts as the end")
    func pastTheEnd() {
        #expect(TranscriptAnchor.isAtEnd(offset: 19_500, contentHeight: 20_000, viewportHeight: 800))
    }

    @Test("content that fits is at its end wherever the offset says")
    func shortContentIsAtItsEnd() {
        #expect(TranscriptAnchor.isAtEnd(offset: 0, contentHeight: 300, viewportHeight: 800))
    }

    @Test("a reader at the end who never asked for it is still kept there")
    func atTheEndWithoutAsking() {
        #expect(
            TranscriptAnchor.place(
                holdsEnd: false, wasAtEnd: true, followerDriving: false, hasAnchor: true
            ) == .end
        )
    }

    @Test("a reader who scrolled away keeps their own row")
    func scrolledAwayKeepsTheRow() {
        #expect(
            TranscriptAnchor.place(
                holdsEnd: false, wasAtEnd: false, followerDriving: false, hasAnchor: true
            ) == .anchor
        )
    }

    @Test("asking for the end out loud survives everything")
    func holdingTheEndWins() {
        for driving in [false, true] {
            for wasAtEnd in [false, true] {
                #expect(
                    TranscriptAnchor.place(
                        holdsEnd: true, wasAtEnd: wasAtEnd,
                        followerDriving: driving, hasAnchor: true
                    ) == .end
                )
            }
        }
    }

    @Test("the follower driving takes the end away from a reader who only happened to be at it")
    func followerOutranksHavingBeenAtTheEnd() {
        #expect(
            TranscriptAnchor.place(
                holdsEnd: false, wasAtEnd: true, followerDriving: true, hasAnchor: true
            ) == .anchor
        )
    }

    @Test("nothing to anchor to is nothing to do")
    func noAnchorIsNoMove() {
        #expect(
            TranscriptAnchor.place(
                holdsEnd: false, wasAtEnd: false, followerDriving: false, hasAnchor: false
            ) == .stay
        )
    }
}
