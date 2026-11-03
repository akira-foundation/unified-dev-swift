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
        #expect(result.size.width >= 0 && result.size.height == 100)
        #expect(corner.size.width >= 0 && corner.size.height >= 0)
        #expect(corner.origin.x <= 300 && corner.origin.y <= 200)
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
        let target = CanvasMove.resized(element.id, handle: .bottomRight, to: CanvasPoint(x: 1_110, y: 610), keepingAspect: false, in: document)
        let operations = target.map { CanvasMove.operations(placing: element.id, at: $0, in: document) } ?? []
        var session = CanvasDocumentSession(document: document)
        _ = session.apply(operations, by: .owner)
        #expect(session.document.elements.first?.rect == CanvasRect(x: 10, y: 10, width: 100, height: 100))
        #expect(session.document.elements.first?.frameID == frame.id)
    }
}
