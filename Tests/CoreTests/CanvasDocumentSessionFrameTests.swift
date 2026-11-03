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

    @Test("a frame larger than the editor allows is refused, so no render can be asked to draw it")
    func frameSizeIsBounded() {
        var session = session()
        let huge = CanvasFrame(id: CanvasFrameID("huge"), name: "Huge", rect: CanvasRect(x: 0, y: 0, width: 1e300, height: 10))
        let atLimit = CanvasFrame(id: CanvasFrameID("ok"), name: "Ok", rect: CanvasRect(x: 0, y: 0, width: 8_192, height: 8_192))
        let grown = CanvasFramePatch(rect: CanvasRect(x: 0, y: 0, width: 8_193, height: 10))

        let added = session.apply([.addFrame(huge)], by: .agent)
        let resized = session.apply([.updateFrame(frameID, expectedRevision: 3, grown)], by: .agent)
        let fits = session.apply([.addFrame(atLimit)], by: .agent)

        guard case .invalid(let one) = added, case .invalid(let two) = resized else {
            Issue.record("expected two refusals")
            return
        }
        #expect(one.contains("8192"))
        #expect(two.contains("8192"))
        guard case .applied = fits else {
            Issue.record("a frame of 8192 points must be accepted")
            return
        }
    }

    @Test("a frame already larger than the limit on disk can still be renamed and recoloured, but not resized")
    func oversizedFrameOnDiskStaysEditable() {
        var oversized = session().document
        oversized.frames[0].rect = CanvasRect(x: 0, y: 0, width: 9_000, height: 10)
        var session = CanvasDocumentSession(document: oversized)

        let renamed = session.apply([.updateFrame(frameID, expectedRevision: 3, CanvasFramePatch(name: "Renamed", fill: "#000000"))], by: .agent)
        let resized = session.apply([.updateFrame(frameID, expectedRevision: 4, CanvasFramePatch(rect: CanvasRect(x: 0, y: 0, width: 9_500, height: 10)))], by: .agent)

        guard case .applied(let document) = renamed else {
            Issue.record("a rename must be accepted, got \(renamed)")
            return
        }
        #expect(document.frames[0].name == "Renamed")
        guard case .invalid = resized else {
            Issue.record("a resize beyond the limit must be refused")
            return
        }
    }
}
