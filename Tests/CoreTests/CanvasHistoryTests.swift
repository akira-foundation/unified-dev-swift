import Foundation
import Testing
@testable import Core

@Suite("CanvasHistory")
struct CanvasHistoryTests {
    private let fixture = CanvasSessionFixture()

    private func opened() throws -> CanvasDocumentKeeper {
        let bytes = try CanvasDocumentCodec.encode(fixture.session().document)
        return CanvasDocumentKeeper(opening: .read(bytes))
    }

    private func held(_ keeper: CanvasDocumentKeeper) throws -> CanvasDocument {
        guard case .document(let document) = keeper.document else {
            throw CanvasHistoryFailure.noDocument
        }
        return document
    }

    private func element(_ id: CanvasElementID, in document: CanvasDocument) -> CanvasElement? {
        document.elements.first { $0.id == id }
    }

    private func comment() -> CanvasComment {
        CanvasComment(anchor: CanvasPoint(x: 1, y: 1), text: "Move this", createdAt: Date(timeIntervalSince1970: 1_000))
    }

    @Test func undoRestoresElementsButKeepsComments() {
        let before = fixture.session().document
        var history = CanvasHistory()
        history.record(before: before)
        var current = before
        current.elements[0].rect = CanvasRect(x: 9, y: 9, width: 50, height: 20)
        current.elements[0].revision += 1
        current.comments = [comment()]

        let restored = history.undo(current: current)

        #expect(restored?.elements[0].rect == before.elements[0].rect)
        #expect(restored?.comments == current.comments)
    }

    @Test func redoKeepsCommentsAddedAfterTheUndo() throws {
        let before = fixture.session().document
        var history = CanvasHistory()
        history.record(before: before)
        var current = before
        current.elements.removeLast()
        let undone = history.undo(current: current)
        var withComment = try #require(undone)
        withComment.comments = [comment()]

        let redone = history.redo(current: withComment)

        #expect(redone?.elements.count == current.elements.count)
        #expect(redone?.comments == withComment.comments)
    }

    @Test func undoBumpsRevisions() throws {
        var keeper = try opened()
        _ = keeper.apply([fixture.move(fixture.boxID, revision: nil)], by: .owner)
        let edited = try held(keeper)
        let revisionBeforeUndo = try #require(element(fixture.boxID, in: edited)?.revision)
        let revisionBeforeEdit = try #require(element(fixture.boxID, in: fixture.session().document)?.revision)

        let undone = keeper.undo()
        #expect(undone)

        let staleCurrent = keeper.apply([fixture.move(fixture.boxID, revision: revisionBeforeUndo)], by: .agent)
        let staleOriginal = keeper.apply([fixture.move(fixture.boxID, revision: revisionBeforeEdit)], by: .agent)
        guard case .conflict = staleCurrent, case .conflict = staleOriginal else {
            Issue.record("a revision from before the undo was accepted: \(String(describing: staleCurrent)), \(String(describing: staleOriginal))")
            return
        }
    }

    @Test func redoBumpsRevisionsToo() throws {
        var keeper = try opened()
        _ = keeper.apply([fixture.move(fixture.boxID, revision: nil)], by: .owner)
        let undone = keeper.undo()
        let afterUndo = try #require(element(fixture.boxID, in: held(keeper))?.revision)
        let redone = keeper.redo()
        #expect(undone && redone)

        let stale = keeper.apply([fixture.move(fixture.boxID, revision: afterUndo)], by: .agent)

        guard case .conflict = stale else {
            Issue.record("a revision from before the redo was accepted: \(String(describing: stale))")
            return
        }
    }

    @Test func undoLeavesAnElementItDidNotChangeAtItsRevision() throws {
        var keeper = try opened()
        _ = keeper.apply([fixture.move(fixture.boxID, revision: nil)], by: .owner)
        let titleRevision = try #require(element(fixture.titleID, in: held(keeper))?.revision)
        let undone = keeper.undo()
        #expect(undone)

        let edit = keeper.apply([fixture.move(fixture.titleID, revision: titleRevision)], by: .agent)

        guard case .applied = edit else {
            Issue.record("an untouched element conflicted after undo: \(String(describing: edit))")
            return
        }
    }

    @Test func aDeletedElementComesBackWithAHigherRevision() throws {
        var keeper = try opened()
        let original = try #require(element(fixture.boxID, in: held(keeper))?.revision)
        _ = keeper.apply([.deleteElement(fixture.boxID, expectedRevision: nil)], by: .owner)

        let undone = keeper.undo()
        #expect(undone)

        let restored = try #require(element(fixture.boxID, in: held(keeper))?.revision)
        #expect(restored > original)
    }

    @Test func oneAgentEditIsOneUndoStep() throws {
        var keeper = try opened()
        let original = try held(keeper)
        let title = try #require(element(fixture.titleID, in: original)?.revision)
        let box = try #require(element(fixture.boxID, in: original)?.revision)
        _ = keeper.apply(
            [fixture.move(fixture.titleID, revision: title), fixture.move(fixture.boxID, revision: box)],
            by: .agent
        )

        let undone = keeper.undo()
        #expect(undone)

        let after = try held(keeper)
        #expect(element(fixture.titleID, in: after)?.rect == element(fixture.titleID, in: original)?.rect)
        #expect(element(fixture.boxID, in: after)?.rect == element(fixture.boxID, in: original)?.rect)
        let another = keeper.undo()
        #expect(!another)
    }

    @Test func aNewApplyClearsRedo() throws {
        var keeper = try opened()
        _ = keeper.apply([fixture.move(fixture.boxID, revision: nil)], by: .owner)
        let undone = keeper.undo()
        #expect(undone)
        _ = keeper.apply([fixture.move(fixture.titleID, revision: nil)], by: .owner)

        let redone = keeper.redo()

        #expect(!redone)
    }

    @Test func aRefusedEditIsNotAStep() throws {
        var keeper = try opened()
        _ = keeper.apply([fixture.move(CanvasElementID("nope"), revision: nil)], by: .owner)
        _ = keeper.apply([fixture.move(fixture.boxID, revision: 99)], by: .agent)
        _ = keeper.apply([], by: .owner)

        let undone = keeper.undo()

        #expect(!undone)
        #expect(keeper.nextStep() == nil)
    }

    @Test func historyIsCappedAtAHundredSteps() {
        var history = CanvasHistory()
        var current = fixture.session().document
        for step in 0..<(CanvasHistory.limit + 20) {
            history.record(before: current)
            current.elements[0].rect = CanvasRect(x: Double(step), y: 0, width: 1, height: 1)
        }

        var undone = 0
        while let restored = history.undo(current: current) {
            current = restored
            undone += 1
        }

        #expect(CanvasHistory.limit == 100)
        #expect(undone == 100)
        #expect(current.elements[0].rect.origin.x == 19)
    }

    @Test func aReloadClearsHistory() throws {
        var keeper = try opened()
        _ = keeper.apply([fixture.move(fixture.boxID, revision: nil)], by: .owner)
        #expect(keeper.nextStep() != nil)
        let written = try CanvasDocumentCodec.encode(held(keeper))
        keeper.finish(.written(written))
        var outside = try held(keeper)
        outside.elements.removeAll()
        let bytes = try CanvasDocumentCodec.encode(outside)

        keeper.perform(.reload)
        #expect(keeper.nextStep() == .read)
        keeper.finish(.read(bytes))
        #expect(keeper.nextStep() != nil)
        keeper.finish(.backedUp("/tmp/copy"))

        let undone = keeper.undo()
        #expect(!undone)
        #expect(keeper.reloads == 1)
    }
}

private enum CanvasHistoryFailure: Error {
    case noDocument
}
