import Testing
@testable import Core

@Suite("CanvasResize")
struct CanvasResizeTests {
    private let rect = CanvasRect(x: 100, y: 100, width: 200, height: 100)

    @Test func resizeKeepsAspect() {
        let result = CanvasResize.resized(rect, handle: .bottomRight, to: CanvasPoint(x: 500, y: 250), keepingAspect: true)
        #expect(result.origin == rect.origin)
        #expect(result.size.width == 400)
        #expect(result.size.height == 200)
    }

    @Test func resizeFromTheTopLeftAnchorsTheBottomRight() {
        let result = CanvasResize.resized(rect, handle: .topLeft, to: CanvasPoint(x: 50, y: 80), keepingAspect: false)
        #expect(result == CanvasRect(x: 50, y: 80, width: 250, height: 120))
    }

    @Test func resizeNeverGoesNegative() {
        let result = CanvasResize.resized(rect, handle: .right, to: CanvasPoint(x: -400, y: 0), keepingAspect: false)
        let corner = CanvasResize.resized(rect, handle: .topLeft, to: CanvasPoint(x: 900, y: 900), keepingAspect: true)
        #expect(result == CanvasRect(x: 100, y: 100, width: CanvasResize.minimumSide, height: 100))
        #expect(corner == CanvasRect(
            x: 300 - 2 * CanvasResize.minimumSide, y: 200 - CanvasResize.minimumSide,
            width: 2 * CanvasResize.minimumSide, height: CanvasResize.minimumSide
        ))
    }

    @Test func edgeHandleOnlyChangesOneDimension() {
        let result = CanvasResize.resized(rect, handle: .bottom, to: CanvasPoint(x: 0, y: 400), keepingAspect: false)
        #expect(result == CanvasRect(x: 100, y: 100, width: 200, height: 300))
    }

    @Test func resizingAnElementInAFrameWritesFrameLocalRect() {
        let frame = CanvasFrame(id: CanvasFrameID("f"), name: "F", rect: CanvasRect(x: 1_000, y: 500, width: 400, height: 400))
        let element = CanvasElement(
            id: CanvasElementID("e"), frameID: frame.id,
            rect: CanvasRect(x: 10, y: 10, width: 50, height: 50), kind: .shape(CanvasShape(kind: .rectangle))
        )
        let document = CanvasDocument(frames: [frame], elements: [element])
        let target = CanvasMove.resized(element.id, handle: .bottomRight, translatedBy: CanvasPoint(x: 50, y: 50), keepingAspect: false, in: document)
        let operations = target.map { CanvasMove.operations(placing: element.id, at: $0, in: document) } ?? []
        var session = CanvasDocumentSession(document: document)
        _ = session.apply(operations, by: .owner)
        #expect(session.document.elements.first?.rect == CanvasRect(x: 10, y: 10, width: 100, height: 100))
        #expect(session.document.elements.first?.frameID == frame.id)
    }

    private func near(_ a: CanvasPoint, _ b: CanvasPoint) -> Bool {
        abs(a.x - b.x) < 1e-9 && abs(a.y - b.y) < 1e-9
    }

    @Test func zeroRotationMatchesThePlainResize() {
        let target = CanvasPoint(x: 420, y: 310)
        for handle in CanvasResizeHandle.allCases {
            for aspect in [false, true] {
                let plain = CanvasResize.resized(rect, handle: handle, to: target, keepingAspect: aspect)
                let rotated = CanvasResize.resized(rect, rotation: 0, handle: handle, to: target, keepingAspect: aspect)
                #expect(plain == rotated)
            }
        }
    }

    @Test func rotatedResizeKeepsTheOppositeCornerOnScreen() {
        for rotation in [90.0, 30.0, -4.0] {
            let before = CanvasResize.handlePoint(.topLeft, of: rect, rotation: rotation)
            let reach = CanvasResize.rotated(CanvasPoint(x: 250, y: 120), about: CanvasPoint(x: 0, y: 0), by: rotation)
            let target = CanvasPoint(x: before.x + reach.x, y: before.y + reach.y)
            let resized = CanvasResize.resized(rect, rotation: rotation, handle: .bottomRight, to: target, keepingAspect: false)
            let after = CanvasResize.handlePoint(.topLeft, of: resized, rotation: rotation)
            let dragged = CanvasResize.handlePoint(.bottomRight, of: resized, rotation: rotation)
            #expect(near(before, after))
            #expect(near(dragged, target))
        }
    }

    @Test func aClickWithoutMovementMakesNoOperation() {
        let element = CanvasElement(
            id: CanvasElementID("e"), rect: rect,
            style: CanvasStyle(rotation: 20), kind: .shape(CanvasShape(kind: .rectangle))
        )
        let document = CanvasDocument(elements: [element])
        for handle in CanvasResizeHandle.allCases {
            let still = CanvasMove.operations(
                resizing: element.id, handle: handle, screenTranslation: CanvasPoint(x: 0, y: 0), zoom: 1, keepingAspect: false, in: document
            )
            let jitter = CanvasMove.operations(
                resizing: element.id, handle: handle, screenTranslation: CanvasPoint(x: 1, y: 1), zoom: 1, keepingAspect: false, in: document
            )
            #expect(still.isEmpty && jitter.isEmpty)
        }
        let drag = CanvasMove.operations(
            resizing: element.id, handle: .right, screenTranslation: CanvasPoint(x: 40, y: 0), zoom: 1, keepingAspect: false, in: document
        )
        #expect(drag.count == 1)
    }
}
