import Foundation
import Testing
@testable import Core

@Suite("A canvas document session with strokes")
struct CanvasDocumentSessionStrokeTests {
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

    @Test func aStrokeAlreadyOverTheLimitCanStillBeMoved() {
        let many = (0..<50_000).map { point(Double($0 % 500), Double($0 % 300)) }
        let big = stroke("s", rect: CanvasRect(x: 0, y: 0, width: 500, height: 300), points: many, width: 2)
        var session = CanvasDocumentSession(document: CanvasDocument(elements: [big]))
        let outcome = session.apply(CanvasMove.operations(moving: [big.id], by: point(10, 10), in: session.document), by: .owner)
        guard case .applied = outcome else { Issue.record("not applied: \(outcome)"); return }
        #expect(session.document.elements.first?.rect.origin == point(10, 10))
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

    private func oversize() -> CanvasElement {
        let many = (0..<12_000).map { point(Double($0 % 500), Double(($0 * 7) % 300)) }
        return stroke("s", rect: CanvasRect(x: 0, y: 0, width: 500, height: 300), points: many, width: 2)
    }

    private func patched(_ element: CanvasElement, points: [CanvasPoint]) -> CanvasOperation {
        let own = CanvasStroke(points: points, width: 8, colour: "#112233")
        return .updateElement(element.id, expectedRevision: nil, CanvasElementPatch(kind: .stroke(own)))
    }

    @Test func restylingAnOversizeStrokeKeepsItsPointsAndIsAccepted() {
        let big = oversize()
        var session = CanvasDocumentSession(document: CanvasDocument(elements: [big]))
        let outcome = session.apply([patched(big, points: points(of: big))], by: .owner)
        guard case .applied = outcome else { Issue.record("not applied: \(outcome)"); return }
        #expect(points(of: session.document.elements.first).count == 12_000)
    }

    @Test func aKindPatchThatRaisesTheCountPastTheLimitIsRefused() {
        let big = oversize()
        var session = CanvasDocumentSession(document: CanvasDocument(elements: [big]))
        let outcome = session.apply([patched(big, points: points(of: big) + [point(1, 1)])], by: .owner)
        guard case .invalid = outcome else { Issue.record("expected invalid, got \(outcome)"); return }
        #expect(points(of: session.document.elements.first).count == 12_000)
    }

    @Test func aKindPatchThatLowersTheCountIsAccepted() {
        let big = oversize()
        var session = CanvasDocumentSession(document: CanvasDocument(elements: [big]))
        let outcome = session.apply([patched(big, points: Array(points(of: big).prefix(11_000)))], by: .owner)
        guard case .applied = outcome else { Issue.record("not applied: \(outcome)"); return }
        #expect(points(of: session.document.elements.first).count == 11_000)
    }

    private func crowded() -> CanvasDocument {
        let chunk = (0..<CanvasStrokeBuilder.maximumPoints).map { point(Double($0 % 90), Double($0 % 40)) }
        let count = CanvasStrokeBuilder.maximumDocumentPoints / CanvasStrokeBuilder.maximumPoints + 1
        return CanvasDocument(elements: (0..<count).map {
            stroke("c\($0)", rect: CanvasRect(x: 0, y: 0, width: 100, height: 50), points: chunk, width: 2)
        })
    }

    @Test func aDocumentAlreadyOverTheLimitCanStillBeEditedWithoutGrowing() {
        var session = CanvasDocumentSession(document: crowded())
        let target = session.document.elements[0]
        let moved = CanvasOperation.updateElement(target.id, expectedRevision: nil, CanvasElementPatch(rect: CanvasRect(x: 5, y: 5, width: 100, height: 50)))
        guard case .applied = session.apply([moved], by: .owner) else { Issue.record("a move was refused"); return }
        #expect(session.document.elements[0].rect.origin == point(5, 5))
    }

    @Test func aDocumentAlreadyOverTheLimitRefusesToGrow() {
        var session = CanvasDocumentSession(document: crowded())
        let extra = stroke("extra", rect: CanvasRect(x: 0, y: 0, width: 5, height: 5), points: [point(1, 1)], width: 2)
        guard case .invalid = session.apply([.addElement(extra)], by: .owner) else { Issue.record("growth was accepted"); return }
        #expect(session.document.elements.count == crowded().elements.count)
    }
}
