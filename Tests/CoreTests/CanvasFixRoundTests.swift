import Foundation
import Testing
@testable import Core

@Suite("Strokes, frames and limits after review")
struct CanvasFixRoundTests {
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

    @Test func aRectPatchFromTheAgentScalesAStrokesPoints() {
        let original = stroke("s", rect: CanvasRect(x: 0, y: 0, width: 104, height: 54), points: [point(2, 2), point(102, 52)], width: 4)
        var session = CanvasDocumentSession(document: CanvasDocument(elements: [original]))
        let patch = CanvasElementPatch(rect: CanvasRect(x: 0, y: 0, width: 204, height: 104))
        let outcome = session.apply([.updateElement(original.id, expectedRevision: 0, patch)], by: .agent)
        guard case .applied = outcome else { Issue.record("not applied: \(outcome)"); return }
        #expect(points(of: session.document.elements.first) == [point(2, 2), point(202, 102)])
    }

    @Test func aPatchThatBringsItsOwnPointsIsNotScaledAgain() {
        let original = stroke("s", rect: CanvasRect(x: 0, y: 0, width: 104, height: 54), points: [point(2, 2), point(102, 52)], width: 4)
        var session = CanvasDocumentSession(document: CanvasDocument(elements: [original]))
        let own = CanvasStroke(points: [point(1, 1), point(9, 9)], width: 4, colour: "#000000")
        let patch = CanvasElementPatch(rect: CanvasRect(x: 0, y: 0, width: 204, height: 104), kind: .stroke(own))
        _ = session.apply([.updateElement(original.id, expectedRevision: 0, patch)], by: .agent)
        #expect(points(of: session.document.elements.first) == own.points)
    }

    @Test func resizingScalesFromTheRealBoxOfThePoints() {
        let thick = CanvasStroke(points: [point(3, 3), point(37, 37)], width: 30, colour: "#000000")
        let wide = CanvasStrokeBuilder.resized(thick, from: CanvasSize(width: 40, height: 40), to: CanvasSize(width: 80, height: 80))
        #expect(wide.points == [point(15, 15), point(65, 65)])
        let fat = CanvasStroke(points: [point(3, 3), point(37, 37)], width: 64, colour: "#000000")
        let squeezed = CanvasStrokeBuilder.resized(fat, from: CanvasSize(width: 40, height: 40), to: CanvasSize(width: 80, height: 80))
        #expect(squeezed.points == [point(32, 32), point(48, 48)])
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

    @Test func aStrokeAlreadyOverTheLimitCanStillBeMoved() {
        let many = (0..<50_000).map { point(Double($0 % 500), Double($0 % 300)) }
        let big = stroke("s", rect: CanvasRect(x: 0, y: 0, width: 500, height: 300), points: many, width: 2)
        var session = CanvasDocumentSession(document: CanvasDocument(elements: [big]))
        let outcome = session.apply(CanvasMove.operations(moving: [big.id], by: point(10, 10), in: session.document), by: .owner)
        guard case .applied = outcome else { Issue.record("not applied: \(outcome)"); return }
        #expect(session.document.elements.first?.rect.origin == point(10, 10))
    }

    @Test func readingAFileWithAnOversizeStrokeSimplifiesIt() throws {
        let many = (0..<50_000).map { point(Double($0 % 500), Double(($0 * 7) % 300)) }
        let big = stroke("s", rect: CanvasRect(x: 0, y: 0, width: 500, height: 300), points: many, width: 2)
        let data = try CanvasDocumentCodec.encode(CanvasDocument(elements: [big]))
        guard case .document(let read) = CanvasDocumentCodec.decode(data) else { Issue.record("not a document"); return }
        #expect(!points(of: read.elements.first).isEmpty)
        #expect(points(of: read.elements.first).count <= CanvasStrokeBuilder.maximumPoints)
    }

    @Test func theDocumentAsAWholeHasAPointLimit() {
        let chunk = (0..<CanvasStrokeBuilder.maximumPoints).map { point(Double($0 % 90), Double($0 % 40)) }
        let strokes = (0..<(CanvasStrokeBuilder.maximumDocumentPoints / CanvasStrokeBuilder.maximumPoints + 1)).map {
            stroke("s\($0)", rect: CanvasRect(x: 0, y: 0, width: 100, height: 50), points: chunk, width: 2)
        }
        var session = CanvasDocumentSession(document: CanvasDocument())
        let outcome = session.apply(strokes.map { .addElement($0) }, by: .agent)
        guard case .invalid(let reason) = outcome else { Issue.record("expected invalid, got \(outcome)"); return }
        #expect(reason.contains("\(CanvasStrokeBuilder.maximumDocumentPoints)"))
        #expect(session.document.elements.isEmpty)
    }
}
