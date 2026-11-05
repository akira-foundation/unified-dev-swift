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

    @Test func framesAtTheSameXFollowTopToBottom() {
        let stacked = [frame("lower", x: 0, y: 500), frame("upper", x: 0, y: 0), frame("right", x: 900)]
        var playback = CanvasPlayback(frames: stacked)
        var seen = [playback.frame?.id]
        playback.next()
        seen.append(playback.frame?.id)
        playback.next()
        seen.append(playback.frame?.id)
        #expect(seen == [CanvasFrameID("upper"), CanvasFrameID("lower"), CanvasFrameID("right")])
    }

    @Test func anUpdateKeepsTheSameOrderForFramesAtTheSameX() {
        var playback = CanvasPlayback(frames: [frame("a", x: 0)])
        playback.update(frames: [frame("lower", x: 0, y: 500), frame("upper", x: 0, y: 0)])
        #expect(playback.frames.map(\.id) == [CanvasFrameID("upper"), CanvasFrameID("lower")])
    }

    @Test func theFitScaleIsFiniteForAnyFrameSize() {
        #expect(CanvasPlayback.fitScale(of: CanvasSize(width: 1_080, height: 540), in: CanvasSize(width: 540, height: 540)) == 0.5)
        #expect(CanvasPlayback.fitScale(of: CanvasSize(width: 0, height: 540), in: CanvasSize(width: 540, height: 540)) == 1)
        #expect(CanvasPlayback.fitScale(of: CanvasSize(width: 100, height: 100), in: CanvasSize(width: -20, height: 540)) == 1)
    }

    @Test func playbackShowsOnlyWhatSitsInAFrame() {
        let slide = frame("a", x: 0)
        let inside = CanvasElement(id: CanvasElementID("in"), frameID: slide.id, rect: CanvasRect(x: 0, y: 0, width: 5, height: 5), kind: .shape(CanvasShape(kind: .rectangle)))
        let loose = CanvasElement(id: CanvasElementID("out"), rect: CanvasRect(x: 0, y: 0, width: 5, height: 5), kind: .shape(CanvasShape(kind: .rectangle)))
        let document = CanvasDocument(frames: [slide], elements: [inside, loose])
        #expect(document.elements(in: slide.id).map(\.id) == [inside.id])
        #expect(document.looseElementCount == 1)
    }
}
