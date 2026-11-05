import Foundation
import Testing
@testable import Core

@Suite("Moving elements between frames")
struct CanvasMoveTests {
    private func point(_ x: Double, _ y: Double) -> CanvasPoint { CanvasPoint(x: x, y: y) }

    private func stroke(_ id: String, rect: CanvasRect, points: [CanvasPoint], width: Double, frame: CanvasFrameID? = nil) -> CanvasElement {
        CanvasElement(
            id: CanvasElementID(id), frameID: frame, rect: rect,
            kind: .stroke(CanvasStroke(points: points, width: width, colour: "#000000"))
        )
    }

    private func points(of element: CanvasElement?) -> [CanvasPoint] {
        guard case .stroke(let stroke)? = element?.kind else { return [] }
        return stroke.points
    }

    @Test func draggingAnElementIntoAnotherFrameMovesItThere() {
        let one = CanvasFrame(id: CanvasFrameID("one"), name: "One", rect: CanvasRect(x: 0, y: 0, width: 500, height: 500))
        let two = CanvasFrame(id: CanvasFrameID("two"), name: "Two", rect: CanvasRect(x: 600, y: 0, width: 500, height: 500))
        let mover = stroke("s", rect: CanvasRect(x: 100, y: 100, width: 100, height: 100), points: [point(5, 5)], width: 10, frame: one.id)
        let document = CanvasDocument(frames: [one, two], elements: [mover])
        var session = CanvasDocumentSession(document: document)
        _ = session.apply(CanvasMove.operations(moving: [mover.id], by: point(550, 0), in: document), by: .owner)
        let moved = session.document.elements.first
        #expect(moved?.frameID == two.id)
        #expect(moved?.rect.origin == point(50, 100))
    }

    @Test func draggingAnElementOutOfEveryFrameLeavesItLoose() {
        let frame = CanvasFrame(id: CanvasFrameID("f"), name: "F", rect: CanvasRect(x: 0, y: 0, width: 500, height: 500))
        let mover = stroke("s", rect: CanvasRect(x: 100, y: 100, width: 100, height: 100), points: [point(5, 5)], width: 10, frame: frame.id)
        let document = CanvasDocument(frames: [frame], elements: [mover])
        var session = CanvasDocumentSession(document: document)
        _ = session.apply(CanvasMove.operations(moving: [mover.id], by: point(900, 0), in: document), by: .owner)
        #expect(session.document.elements.first?.frameID == nil)
        #expect(session.document.elements.first?.rect.origin == point(1_000, 100))
    }

    @Test func aLooseElementDraggedIntoAFrameJoinsIt() {
        let frame = CanvasFrame(id: CanvasFrameID("f"), name: "F", rect: CanvasRect(x: 1_000, y: 0, width: 500, height: 500))
        let loose = stroke("s", rect: CanvasRect(x: 100, y: 100, width: 100, height: 100), points: [point(5, 5)], width: 10)
        let document = CanvasDocument(frames: [frame], elements: [loose])
        var session = CanvasDocumentSession(document: document)
        _ = session.apply(CanvasMove.operations(moving: [loose.id], by: point(950, 0), in: document), by: .owner)
        #expect(session.document.elements.first?.frameID == frame.id)
        #expect(session.document.elements.first?.rect.origin == point(50, 100))
    }
}
