import Foundation
import Testing
@testable import Core

@Suite("A canvas document session and its frames")
struct CanvasDocumentSessionFrameTests {
    private let fixture = CanvasSessionFixture()
    private var frameID: CanvasFrameID { fixture.frameID }
    private var titleID: CanvasElementID { fixture.titleID }
    private var boxID: CanvasElementID { fixture.boxID }
    private func session() -> CanvasDocumentSession { fixture.session() }
    private func move(_ id: CanvasElementID, revision: Int?) -> CanvasOperation { fixture.move(id, revision: revision) }

    @Test("an agent cannot delete a frame whose contents changed after it read the frame")
    func agentCannotDeleteAFrameWhoseContentsChanged() {
        var session = session()
        _ = session.apply([move(boxID, revision: nil)], by: .owner)
        let before = session.document
        let outcome = session.apply([.deleteFrame(frameID, expectedRevision: 3)], by: .agent)

        guard case .conflict(let conflicts) = outcome else {
            Issue.record("expected conflict, got \(outcome)")
            return
        }
        #expect(conflicts.map(\.target) == ["f1"])
        #expect(conflicts.map(\.revision) == [4])
        #expect(session.document == before)
    }

    @Test("adding, deleting, reordering and moving an element across frames bump the frames involved")
    func frameRevisionFollowsItsContents() {
        var session = session()
        let other = CanvasFrame(id: CanvasFrameID("f2"), name: "Two", rect: CanvasRect(x: 200, y: 0, width: 100, height: 100))
        let added = CanvasElement(
            id: CanvasElementID("new"), frameID: frameID,
            rect: CanvasRect(x: 0, y: 0, width: 1, height: 1), kind: .shape(CanvasShape(kind: .ellipse))
        )
        _ = session.apply([.addFrame(other), .addElement(added)], by: .owner)
        #expect(session.document.frames.map(\.revision) == [4, 0])
        _ = session.apply([.updateElement(boxID, expectedRevision: nil, CanvasElementPatch(frameID: other.id))], by: .owner)
        #expect(session.document.frames.map(\.revision) == [5, 1])
        _ = session.apply([.deleteElement(added.id, expectedRevision: nil)], by: .owner)
        #expect(session.document.frames.map(\.revision) == [6, 1])
        _ = session.apply([.reorder(titleID, toIndex: 0)], by: .owner)
        #expect(session.document.frames.map(\.revision) == [7, 1])
    }

    @Test("beginning to edit an element in a frame refuses an agent frame change made before it")
    func beginEditingBumpsTheFrame() {
        var session = session()
        session.beginEditing(boxID)
        let outcome = session.apply([.deleteFrame(frameID, expectedRevision: 3)], by: .agent)

        guard case .conflict(let conflicts) = outcome else {
            Issue.record("expected conflict, got \(outcome)")
            return
        }
        #expect(conflicts.map(\.revision) == [4])
    }

    @Test("a stroke or style value that cannot be drawn is invalid and names the operation")
    func drawingValuesAreValidated() {
        func stroked(width: Double, x: Double) -> CanvasElement {
            CanvasElement(
                id: CanvasElementID("s"), frameID: frameID,
                rect: CanvasRect(x: 0, y: 0, width: 1, height: 1),
                kind: .stroke(CanvasStroke(points: [CanvasPoint(x: x, y: 0)], width: width, colour: "#000000"))
            )
        }
        let operations: [CanvasOperation] = [
            .addElement(stroked(width: -1, x: 0)),
            .addElement(stroked(width: .nan, x: 0)),
            .addElement(stroked(width: 1, x: .infinity)),
            .updateElement(boxID, expectedRevision: nil, CanvasElementPatch(style: CanvasStylePatch(opacity: 1.5))),
            .updateElement(boxID, expectedRevision: nil, CanvasElementPatch(style: CanvasStylePatch(opacity: -0.1))),
            .updateElement(boxID, expectedRevision: nil, CanvasElementPatch(style: CanvasStylePatch(opacity: .nan))),
            .updateElement(boxID, expectedRevision: nil, CanvasElementPatch(style: CanvasStylePatch(strokeWidth: -2))),
        ]

        for operation in operations {
            var session = session()
            let outcome = session.apply([move(titleID, revision: nil), operation], by: .owner)
            guard case .invalid(let reason) = outcome else {
                Issue.record("expected invalid for \(operation), got \(outcome)")
                continue
            }
            #expect(reason.contains("index 1"))
        }
    }
}
