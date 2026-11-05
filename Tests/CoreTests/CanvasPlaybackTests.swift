import Testing
@testable import Core

@Suite("CanvasPlayback")
struct CanvasPlaybackTests {
    private func frame(_ id: String, x: Double, y: Double = 0) -> CanvasFrame {
        CanvasFrame(id: CanvasFrameID(id), name: id, rect: CanvasRect(x: x, y: y, width: 100, height: 100))
    }

    private var scattered: [CanvasFrame] { [frame("c", x: 2_000), frame("a", x: 0), frame("b", x: 1_000)] }

    @Test func playbackFollowsSlideOrder() {
        var playback = CanvasPlayback(frames: scattered)
        var seen = [playback.frame?.id]
        playback.next()
        seen.append(playback.frame?.id)
        playback.next()
        seen.append(playback.frame?.id)
        #expect(seen == CanvasExportNames.slideOrder(scattered).map { Optional($0.id) })
        #expect(seen == [CanvasFrameID("a"), CanvasFrameID("b"), CanvasFrameID("c")])
    }

    @Test func playbackStopsAtTheEnds() {
        var playback = CanvasPlayback(frames: scattered)
        playback.previous()
        let atStart = playback.current
        for _ in 0..<10 { playback.next() }
        #expect(atStart == 0 && playback.current == 2 && playback.isAtEnd)
        for _ in 0..<10 { playback.previous() }
        #expect(playback.current == 0 && playback.isAtStart)
    }

    @Test func playbackWithNoFramesIsSafe() {
        var playback = CanvasPlayback(frames: [])
        playback.next()
        playback.previous()
        #expect(playback.current == 0 && playback.frame == nil && playback.count == 0)
    }

    @Test func playbackStartsAtTheNamedFrame() {
        let playback = CanvasPlayback(frames: scattered, startingAt: CanvasFrameID("c"))
        #expect(playback.frame?.id == CanvasFrameID("c"))
    }

    @Test func playbackKeepsTheSlideWhenOthersMoveOrAppear() {
        var playback = CanvasPlayback(frames: scattered, startingAt: CanvasFrameID("b"))
        playback.update(frames: scattered + [frame("z", x: -500)])
        #expect(playback.frame?.id == CanvasFrameID("b") && playback.current == 2)
    }

    @Test func playbackStaysValidWhenItsFrameIsDeleted() {
        var playback = CanvasPlayback(frames: scattered, startingAt: CanvasFrameID("c"))
        playback.update(frames: [frame("a", x: 0), frame("b", x: 1_000)])
        #expect(playback.current == 1 && playback.frame?.id == CanvasFrameID("b"))
    }

    @Test func playbackStaysValidWhenEveryFrameGoes() {
        var playback = CanvasPlayback(frames: scattered, startingAt: CanvasFrameID("c"))
        playback.update(frames: [])
        let empty = (playback.current, playback.frame)
        playback.next()
        playback.update(frames: [frame("n", x: 0)])
        #expect(empty.0 == 0 && empty.1 == nil)
        #expect(playback.current == 0 && playback.frame?.id == CanvasFrameID("n"))
    }
}
