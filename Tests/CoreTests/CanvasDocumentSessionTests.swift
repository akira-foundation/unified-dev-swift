import Foundation
import Testing
@testable import Core

@Suite("A canvas document session")
struct CanvasDocumentSessionTests {
    private let fixture = CanvasSessionFixture()
    private var frameID: CanvasFrameID { fixture.frameID }
    private var titleID: CanvasElementID { fixture.titleID }
    private var boxID: CanvasElementID { fixture.boxID }
    private func session() -> CanvasDocumentSession { fixture.session() }
    private func move(_ id: CanvasElementID, revision: Int?) -> CanvasOperation { fixture.move(id, revision: revision) }

    @Test("a batch with an invalid second operation leaves the document intact")
    func applyIsAllOrNothing() {
        var session = session()
        let before = session.document
        let outcome = session.apply(
            [move(titleID, revision: 2), .deleteElement(CanvasElementID("nope"), expectedRevision: 0)],
            by: .agent
        )

        guard case .invalid(let reason) = outcome else {
            Issue.record("expected invalid, got \(outcome)")
            return
        }
        #expect(reason.contains("index 1"))
        #expect(session.document == before)
    }

    @Test("every applied change bumps the revision of what it touched")
    func everyAppliedChangeBumpsRevision() {
        var session = session()
        let outcome = session.apply([
            move(titleID, revision: 2),
            .updateFrame(frameID, expectedRevision: 3, CanvasFramePatch(name: "Cover")),
            .reorder(boxID, toIndex: 0),
        ], by: .agent)

        guard case .applied(let document) = outcome else {
            Issue.record("expected applied, got \(outcome)")
            return
        }
        #expect(document.elements.first { $0.id == titleID }?.revision == 3)
        #expect(document.frames.first?.revision == 6)
        #expect(document.frames.first?.name == "Cover")
        #expect(document.elements.map(\.id) == [boxID, titleID])
        #expect(document.elements.first?.revision == 1)
    }

    @Test("an agent holding a stale revision gets every conflict with the current state, and nothing applies")
    func agentStaleRevisionIsAConflict() {
        var session = session()
        let before = session.document
        let outcome = session.apply([
            move(titleID, revision: 1),
            move(boxID, revision: 0),
            .deleteFrame(frameID, expectedRevision: 0),
        ], by: .agent)

        guard case .conflict(let conflicts) = outcome else {
            Issue.record("expected conflict, got \(outcome)")
            return
        }
        #expect(conflicts.map(\.target) == ["title", "f1"])
        #expect(conflicts.map(\.revision) == [2, 3])
        #expect(conflicts.first?.current == .element(before.elements[0]))
        #expect(conflicts.last?.current == .frame(before.frames[0]))
        #expect(session.document == before)
    }

    @Test("an agent change without an expected revision is invalid")
    func agentNeedsRevision() {
        var session = session()
        let outcome = session.apply([move(titleID, revision: nil)], by: .agent)

        guard case .invalid(let reason) = outcome else {
            Issue.record("expected invalid, got \(outcome)")
            return
        }
        #expect(reason.contains("expectedRevision"))
    }

    @Test("the owner is never checked against a revision")
    func ownerNeverConflicts() {
        var session = session()
        let outcome = session.apply([move(titleID, revision: 0), move(boxID, revision: nil)], by: .owner)

        guard case .applied(let document) = outcome else {
            Issue.record("expected applied, got \(outcome)")
            return
        }
        #expect(document.elements.map(\.rect.origin.x) == [9, 9])
    }

    @Test("beginning to edit bumps the revision so an agent change made before it is refused")
    func beginEditingBeatsTheAgent() {
        var session = session()
        session.beginEditing(titleID)
        let outcome = session.apply([move(titleID, revision: 2)], by: .agent)

        guard case .conflict(let conflicts) = outcome else {
            Issue.record("expected conflict, got \(outcome)")
            return
        }
        #expect(conflicts.map(\.revision) == [3])
    }

    @Test("an agent can change an element it added earlier in the same batch")
    func addedInBatch() {
        var session = session()
        let added = CanvasElement(
            id: CanvasElementID("new"), frameID: frameID,
            rect: CanvasRect(x: 0, y: 0, width: 1, height: 1), kind: .shape(CanvasShape(kind: .ellipse))
        )
        let outcome = session.apply([.addElement(added), move(added.id, revision: nil)], by: .agent)

        guard case .applied(let document) = outcome else {
            Issue.record("expected applied, got \(outcome)")
            return
        }
        #expect(document.elements.last?.rect.origin.x == 9)
    }

    @Test("two changes to one element in one batch both use the revision the agent read")
    func twoChangesOneBatch() {
        var session = session()
        let outcome = session.apply([
            move(titleID, revision: 2),
            .updateElement(titleID, expectedRevision: 2, CanvasElementPatch(style: CanvasStylePatch(opacity: 0.5))),
        ], by: .agent)

        guard case .applied(let document) = outcome else {
            Issue.record("expected applied, got \(outcome)")
            return
        }
        #expect(document.elements[0].revision == 4)
        #expect(document.elements[0].style.opacity == 0.5)
    }

    @Test("deleting a frame deletes the elements in it")
    func deleteFrameDeletesElements() {
        var session = session()
        _ = session.apply([.deleteFrame(frameID, expectedRevision: 3)], by: .agent)

        #expect(session.document.frames.isEmpty)
        #expect(session.document.elements.isEmpty)
    }

    @Test("reorder clamps its index")
    func reorderClamps() {
        var session = session()
        _ = session.apply([.reorder(titleID, toIndex: 99)], by: .owner)
        #expect(session.document.elements.map(\.id) == [boxID, titleID])
        _ = session.apply([.reorder(titleID, toIndex: -4)], by: .owner)
        #expect(session.document.elements.map(\.id) == [titleID, boxID])
    }

    @Test("unknown ids, duplicate ids and bad sizes are invalid")
    func validation() {
        let duplicate = CanvasElement(id: titleID, rect: CanvasRect(x: 0, y: 0, width: 1, height: 1), kind: .shape(CanvasShape(kind: .line)))
        var negative = duplicate
        negative.id = CanvasElementID("neg")
        negative.rect = CanvasRect(x: 0, y: 0, width: -1, height: 1)
        var infinite = negative
        infinite.rect = CanvasRect(x: 0, y: 0, width: .infinity, height: 1)
        let orphan = CanvasElement(
            id: CanvasElementID("orphan"), frameID: CanvasFrameID("ghost"),
            rect: CanvasRect(x: 0, y: 0, width: 1, height: 1), kind: .shape(CanvasShape(kind: .line))
        )
        let operations: [CanvasOperation] = [
            .addElement(duplicate), .addElement(negative), .addElement(infinite), .addElement(orphan),
            .updateFrame(CanvasFrameID("ghost"), expectedRevision: 0, CanvasFramePatch()),
            .addFrame(CanvasFrame(id: frameID, name: "Again", rect: CanvasRect(x: 0, y: 0, width: 1, height: 1))),
        ]

        for operation in operations {
            var session = session()
            let outcome = session.apply([operation], by: .owner)
            guard case .invalid = outcome else {
                Issue.record("expected invalid for \(operation), got \(outcome)")
                continue
            }
        }
    }

    @Test("a patch can change the text, the shape, the stroke and every style field")
    func patchesCoverEveryField() {
        var session = session()
        let runs = CanvasText(runs: [CanvasTextRun(text: "New", fontName: "Menlo", size: 30, weight: 0.4, colour: "#FF0000")], alignment: .centre)
        let style = CanvasStylePatch(
            fill: "#00FF00", stroke: "#0000FF", strokeWidth: 3, cornerRadius: 4, opacity: 0.5, rotation: 12,
            shadow: CanvasShadowPatch(offsetX: 1, offsetY: 2, radius: 3, colour: "#000000")
        )
        _ = session.apply([
            .updateElement(titleID, expectedRevision: nil, CanvasElementPatch(rect: CanvasRect(x: 1, y: 2, width: 3, height: 4), style: style, kind: .text(runs))),
            .updateElement(boxID, expectedRevision: nil, CanvasElementPatch(kind: .stroke(CanvasStroke(points: [CanvasPoint(x: 0, y: 0)], width: 2, colour: "#111111")))),
        ], by: .owner)
        let title = session.document.elements[0]
        let detached = session.apply([
            .updateElement(titleID, expectedRevision: nil, CanvasElementPatch(clearFrame: true, style: CanvasStylePatch(clearFill: true, clearShadow: true))),
        ], by: .owner)

        #expect(title.kind == .text(runs))
        #expect(title.rect == CanvasRect(x: 1, y: 2, width: 3, height: 4))
        #expect(title.style == CanvasStyle(
            fill: "#00FF00", stroke: "#0000FF", strokeWidth: 3, cornerRadius: 4, opacity: 0.5, rotation: 12,
            shadow: CanvasShadow(offsetX: 1, offsetY: 2, radius: 3, colour: "#000000")
        ))
        guard case .stroke = session.document.elements[1].kind else {
            Issue.record("expected a stroke")
            return
        }
        guard case .applied(let document) = detached else {
            Issue.record("expected applied, got \(detached)")
            return
        }
        #expect(document.elements[0].frameID == nil)
        #expect(document.elements[0].style.fill == nil)
        #expect(document.elements[0].style.shadow == nil)
    }

    @Test("operations survive a round trip through JSON")
    func operationsAreCodable() throws {
        let operations: [CanvasOperation] = [
            .addFrame(CanvasFrame(id: frameID, name: "A", rect: CanvasRect(x: 0, y: 0, width: 1, height: 1))),
            .updateFrame(frameID, expectedRevision: 1, CanvasFramePatch(name: "B")),
            .deleteFrame(frameID, expectedRevision: nil),
            .updateElement(titleID, expectedRevision: 2, CanvasElementPatch(style: CanvasStylePatch(opacity: 0.2))),
            .deleteElement(boxID, expectedRevision: 0),
            .reorder(boxID, toIndex: 3),
        ]
        let data = try JSONEncoder().encode(operations)

        #expect(try JSONDecoder().decode([CanvasOperation].self, from: data) == operations)
    }

    @Test("an operation named by the agent that does not exist fails to decode")
    func unknownOperationName() {
        let data = Data(#"[{"op":"explode"}]"#.utf8)

        #expect(throws: DecodingError.self) { try JSONDecoder().decode([CanvasOperation].self, from: data) }
    }
}
