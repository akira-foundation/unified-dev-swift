import Testing
@testable import Core

@Suite("CanvasHitTest")
struct CanvasHitTestTests {
    private func box(_ id: String, _ rect: CanvasRect, frame: CanvasFrameID? = nil, rotation: Double = 0) -> CanvasElement {
        CanvasElement(
            id: CanvasElementID(id), frameID: frame, rect: rect,
            style: CanvasStyle(rotation: rotation), kind: .shape(CanvasShape(kind: .rectangle))
        )
    }

    @Test func topmostElementWins() {
        let document = CanvasDocument(elements: [
            box("under", CanvasRect(x: 0, y: 0, width: 100, height: 100)),
            box("over", CanvasRect(x: 50, y: 50, width: 100, height: 100)),
        ])
        let hit = CanvasHitTest.element(at: CanvasPoint(x: 75, y: 75), in: document)
        let underOnly = CanvasHitTest.element(at: CanvasPoint(x: 10, y: 10), in: document)
        let nothing = CanvasHitTest.element(at: CanvasPoint(x: 400, y: 400), in: document)
        #expect(hit == CanvasElementID("over"))
        #expect(underOnly == CanvasElementID("under"))
        #expect(nothing == nil)
    }

    @Test func rotatedElementHitsItsShape() {
        let wide = box("wide", CanvasRect(x: 0, y: 40, width: 200, height: 20), rotation: 90)
        let document = CanvasDocument(elements: [wide])
        let insideRotated = CanvasHitTest.element(at: CanvasPoint(x: 100, y: 10), in: document)
        let insideOriginal = CanvasHitTest.element(at: CanvasPoint(x: 10, y: 50), in: document)
        #expect(insideRotated == CanvasElementID("wide"))
        #expect(insideOriginal == nil)
    }

    @Test func frameLocalRectsAreAbsolute() {
        let frame = CanvasFrame(
            id: CanvasFrameID("f"), name: "F", rect: CanvasRect(x: 1_000, y: 200, width: 500, height: 500)
        )
        let inside = box("inside", CanvasRect(x: 10, y: 20, width: 30, height: 40), frame: frame.id)
        let document = CanvasDocument(frames: [frame], elements: [inside])
        let absolute = CanvasHitTest.absoluteRect(of: inside, in: document)
        let hit = CanvasHitTest.element(at: CanvasPoint(x: 1_020, y: 230), in: document)
        let miss = CanvasHitTest.element(at: CanvasPoint(x: 20, y: 30), in: document)
        #expect(absolute == CanvasRect(x: 1_010, y: 220, width: 30, height: 40))
        #expect(hit == inside.id)
        #expect(miss == nil)
    }
}
