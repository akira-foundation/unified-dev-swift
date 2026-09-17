import Testing
import Foundation
@testable import Core

@Suite("Following the live end")
struct TranscriptFollowTests {
    @Test("a reader who has scrolled up is never moved")
    func leavesAReaderAlone() {
        let end = 10_000.0
        for gap in [ScrollEnd.threshold + 1, 200, 3_000, 9_000] {
            let move = TranscriptFollow.step(
                offset: end - gap, end: end, frame: 1 / 60, ownsGap: false
            )
            #expect(move == .rest)
        }
    }

    @Test("a reader who has scrolled up keeps their place when content lands")
    func doesNotTakeBackFromAReader() {
        let offset = TranscriptFollow.start(offset: 5_000, end: 10_000, grew: 60, ownsGap: false)
        #expect(offset == 5_000)
    }

    @Test("a view already at the end has nothing to do")
    func restsAtTheEnd() {
        #expect(TranscriptFollow.step(offset: 10_000, end: 10_000, frame: 1 / 60, ownsGap: false) == .rest)
        #expect(TranscriptFollow.step(offset: 9_999.8, end: 10_000, frame: 1 / 60, ownsGap: false) == .rest)
    }

    @Test("content that shrinks under the view is put right at once")
    func snapsBackFromBeyondTheEnd() {
        let move = TranscriptFollow.step(
            offset: 10_400, end: 10_000, frame: 1 / 60, ownsGap: false
        )
        #expect(move == .settle(10_000))
    }

    @Test("a pane with nothing to scroll is left alone")
    func nothingToScroll() {
        #expect(TranscriptFollow.step(offset: 0, end: 0, frame: 1 / 60, ownsGap: false) == .rest)
        #expect(TranscriptFollow.start(offset: 0, end: 0, grew: 60, ownsGap: false) == 0)
    }

    @Test("Reduce Motion is owed no travel")
    func reduceMotion() {
        #expect(TranscriptFollow.travels(reduceMotion: false))
        #expect(!TranscriptFollow.travels(reduceMotion: true))
    }

    @Test("a row landing under a reader at the end is put back by its own height")
    func takesBackTheRow() {
        #expect(TranscriptFollow.start(offset: 10_000, end: 10_000, grew: 22, ownsGap: false) == 9_978)
    }

    @Test("a tall arrival is capped rather than travelled in full")
    func capsTheTakeBack() {
        let offset = TranscriptFollow.start(offset: 10_000, end: 10_000, grew: 4_000, ownsGap: false)
        #expect(offset == 10_000 - TranscriptFollow.takeBack)
    }

    @Test("a full take-back still counts as being at the end")
    func takeBackStaysBelowTheThreshold() {
        let end = 10_000.0
        let offset = TranscriptFollow.start(offset: end, end: end, grew: 5_000, ownsGap: false)
        #expect(
            ScrollEnd.isAtEnd(contentHeight: end + 700, viewportHeight: 700, offset: offset)
        )
    }

    @Test("a few points of streaming text are followed rather than taken back")
    func streamingIsNotTakenBack() {
        #expect(TranscriptFollow.start(offset: 10_000, end: 10_000, grew: 6, ownsGap: false) == 10_000)
        #expect(TranscriptFollow.start(offset: 10_000, end: 10_000, grew: 12, ownsGap: false) == 10_000)
        #expect(TranscriptFollow.start(offset: 10_000, end: 10_000, grew: 22, ownsGap: false) == 9_978)
    }

    @Test("a small arrival mid travel leaves the travel alone")
    func smallArrivalMidTravel() {
        let end = 10_000.0
        let midTravel = end - 40
        #expect(TranscriptFollow.start(offset: midTravel, end: end, grew: 6, ownsGap: true) == midTravel)
    }

    @Test("nothing arriving is nothing to take back")
    func noGrowthNoTakeBack() {
        #expect(TranscriptFollow.start(offset: 10_000, end: 10_000, grew: 0, ownsGap: false) == 10_000)
    }

    @Test("an arrival mid travel does not start the travel again")
    func doesNotRestartMidTravel() {
        let end = 10_000.0
        let midTravel = end - 40
        #expect(TranscriptFollow.start(offset: midTravel, end: end, grew: 22, ownsGap: false) == midTravel)
    }

    @Test("the gap closes, monotonically, and arrives")
    func closesTheGap() {
        var offset = 10_000 - TranscriptFollow.takeBack
        let end = 10_000.0
        var frames = 0
        var last = offset

        while frames < 240 {
            guard case .settle(let next) = TranscriptFollow.step(
                offset: offset, end: end, frame: 1 / 120, ownsGap: false
            ) else { break }
            #expect(next > last || next == end)
            last = next
            offset = next
            frames += 1
            if offset == end { break }
        }

        #expect(offset == end)
        #expect(frames > 4)
        #expect(frames < 60)
    }

    @Test("most of the distance goes in the first third")
    func frontLoaded() {
        let end = 10_000.0
        var offset = end - TranscriptFollow.takeBack
        for _ in 0..<10 {
            guard case .settle(let next) = TranscriptFollow.step(
                offset: offset, end: end, frame: 1 / 120, ownsGap: false
            ) else { break }
            offset = next
        }
        let covered = (offset - (end - TranscriptFollow.takeBack)) / TranscriptFollow.takeBack
        #expect(covered > 0.5)
    }

    @Test("a late frame is not a licence to teleport")
    func clampsALateFrame() {
        let end = 10_000.0
        let offset = end - TranscriptFollow.takeBack
        guard case .settle(let next) = TranscriptFollow.step(
            offset: offset, end: end, frame: 4, ownsGap: false
        ) else {
            Issue.record("a late frame should still move the view")
            return
        }
        let sameAsAnOrdinaryLongFrame = TranscriptFollow.step(
            offset: offset, end: end, frame: TranscriptFollow.longestFrame, ownsGap: false
        )
        #expect(sameAsAnOrdinaryLongFrame == .settle(next))
        #expect(next < end)
    }

    @Test("the last point closes rather than halving forever")
    func closesTheLastPoint() {
        let end = 10_000.0
        var offset = end - 1.5
        var steps = 0

        while steps < 10 {
            guard case .settle(let next) = TranscriptFollow.step(
                offset: offset, end: end, frame: 1 / 120, ownsGap: false
            ) else { break }
            #expect(next - offset >= min(end - offset, TranscriptFollow.smallestStep) - 0.000_1)
            offset = next
            steps += 1
            if offset == end { break }
        }

        #expect(offset == end)
        #expect(steps <= 2)
    }

    @Test("a step never carries the view past the end")
    func neverOvershoots() {
        let end = 10_000.0
        for gap in stride(from: 0.6, through: TranscriptFollow.takeBack, by: 0.3) {
            guard case .settle(let next) = TranscriptFollow.step(
                offset: end - gap, end: end, frame: 1 / 120, ownsGap: false
            ) else { continue }
            #expect(next <= end)
        }
    }

    @Test("a frame of no time at all moves nothing")
    func zeroFrame() {
        let end = 10_000.0
        #expect(TranscriptFollow.step(offset: end - 40, end: end, frame: 0, ownsGap: false) == .rest)
        #expect(TranscriptFollow.step(offset: end - 40, end: end, frame: -1, ownsGap: false) == .rest)
    }

    @Test("a streaming tail is followed without ever looking scrolled away")
    func steadyGrowthStaysAtTheEnd() {
        var end = 10_000.0
        var offset = end
        let frame = 1.0 / 120
        let rate = 600.0

        for _ in 0..<600 {
            let grew = rate * frame
            end += grew
            offset = TranscriptFollow.start(offset: offset, end: end, grew: grew, ownsGap: true)
            if case .settle(let next) = TranscriptFollow.step(offset: offset, end: end, frame: frame, ownsGap: true) {
                offset = next
            }
            #expect(
                ScrollEnd.isAtEnd(contentHeight: end + 700, viewportHeight: 700, offset: offset)
            )
        }

        #expect(end - offset < TranscriptFollow.takeBack)
    }

    @Test("a gap this object opened itself is caught up rather than given up")
    func recoversItsOwnGap() {
        let end = 10_000.0
        let stranded = end - 300
        #expect(
            TranscriptFollow.step(offset: stranded, end: end, frame: 1 / 120, ownsGap: false)
                == .rest
        )
        #expect(
            TranscriptFollow.step(offset: stranded, end: end, frame: 1 / 120, ownsGap: true)
                == .settle(end - TranscriptFollow.takeBack)
        )
    }

    @Test("catching up lands a take-back short, and travels the rest")
    func catchingUpLeavesATravel() {
        let end = 10_000.0
        guard case .settle(let jumped) = TranscriptFollow.step(
            offset: end - 4_000, end: end, frame: 1 / 120, ownsGap: true
        ) else {
            Issue.record("a gap of its own should be caught up")
            return
        }
        #expect(jumped < end)
        #expect(end - jumped == TranscriptFollow.takeBack)
        guard case .settle(let next) = TranscriptFollow.step(
            offset: jumped, end: end, frame: 1 / 120, ownsGap: true
        ) else {
            Issue.record("and then travelled")
            return
        }
        #expect(next > jumped)
        #expect(next < end)
    }

    @Test("arrivals mid travel cannot open the gap past the take-back")
    func ownedGrowthIsCapped() {
        var end = 10_000.0
        var offset = end - 40
        for _ in 0..<20 {
            let grew = 400.0
            end += grew
            offset = TranscriptFollow.start(offset: offset, end: end, grew: grew, ownsGap: true)
            #expect(end - offset <= TranscriptFollow.takeBack)
        }
    }

    @Test("an owned arrival under the cap moves nothing")
    func ownedGrowthUnderTheCapIsANoOp() {
        let grew = 22.0
        let offset = 9_960.0
        let end = 10_000.0 + grew
        #expect(TranscriptFollow.start(offset: offset, end: end, grew: grew, ownsGap: true) == offset)
    }

    @Test("a reader who has scrolled up is left alone whatever arrives")
    func aReaderIsStillLeftAlone() {
        #expect(TranscriptFollow.start(offset: 5_000, end: 10_000, grew: 400, ownsGap: false) == 5_000)
        #expect(
            TranscriptFollow.step(offset: 5_000, end: 10_000, frame: 1 / 120, ownsGap: false)
                == .rest
        )
    }
}
