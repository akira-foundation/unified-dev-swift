import Foundation
import Testing
@testable import Core

@Suite("An agent edit through the keeper")
struct CanvasAgentEditTests {
    private let fixture = CanvasSessionFixture()

    private func opened() throws -> CanvasDocumentKeeper {
        CanvasDocumentKeeper(opening: .read(try CanvasDocumentCodec.encode(fixture.session().document)))
    }

    private func held(_ keeper: CanvasDocumentKeeper) -> CanvasDocument? {
        if case .document(let document) = keeper.document { return document }
        return nil
    }

    private func pending(_ start: CanvasAgentEditStart) -> CanvasPendingAgentEdit? {
        if case .pending(let pending) = start { return pending }
        return nil
    }

    @Test("a change that names no revision is refused and nothing is written to the keeper")
    func agentMustNameTheRevision() throws {
        var keeper = try opened()
        let before = held(keeper)

        let start = CanvasAgentEdit.begin([fixture.move(fixture.boxID, revision: nil)], on: &keeper)

        guard case .refused(let sentence) = start else {
            Issue.record("expected a refusal, got \(start)")
            return
        }
        #expect(sentence.contains("expectedRevision"))
        #expect(sentence.contains("index 0"))
        #expect(held(keeper) == before)
        #expect(keeper.undoDepth == 0)
    }

    @Test("a change with the revision that was read is applied as one undo step, whatever its length")
    func oneCallIsOneUndoStep() throws {
        var keeper = try opened()
        let operations = [
            fixture.move(fixture.boxID, revision: 0),
            fixture.move(fixture.titleID, revision: 2),
            .reorder(fixture.boxID, toIndex: 0),
        ]

        let start = CanvasAgentEdit.begin(operations, on: &keeper)

        #expect(pending(start) != nil)
        #expect(keeper.undoDepth == 1)
        #expect(keeper.recordedSteps == 1)
        #expect(held(keeper)?.elements.first { $0.id == fixture.boxID }?.rect.origin.x == 9)
    }

    @Test("a stale revision is a conflict with the current state, and applies and records nothing")
    func staleRevisionConflicts() throws {
        var keeper = try opened()
        let before = held(keeper)

        let start = CanvasAgentEdit.begin([fixture.move(fixture.titleID, revision: 1)], on: &keeper)

        guard case .conflict(let conflicts) = start else {
            Issue.record("expected a conflict, got \(start)")
            return
        }
        #expect(conflicts.map(\.target) == [fixture.titleID.rawValue])
        #expect(conflicts.first?.revision == 2)
        #expect(held(keeper) == before)
        #expect(keeper.undoDepth == 0)
    }

    @Test("the summary names the new revision of each element and of the frame that rose with it, and what was deleted")
    func summaryCoversTheFrameRevision() throws {
        var keeper = try opened()
        let start = CanvasAgentEdit.begin(
            [fixture.move(fixture.boxID, revision: 0), .deleteElement(fixture.titleID, expectedRevision: 2)], on: &keeper
        )

        let changes = try #require(pending(start)).changes
        let now = try #require(held(keeper))

        #expect(changes.elements == [CanvasRevisionEntry(id: fixture.boxID, revision: 1)])
        #expect(changes.frames.map(\.id) == [fixture.frameID])
        #expect(changes.frames.first?.revision == now.frames[0].revision)
        #expect(changes.frames.first?.revision ?? 0 > 3)
        #expect(changes.deletedElements == [fixture.titleID])
        #expect(changes.deletedFrames.isEmpty)
    }

    @Test("a document under a hold refuses the edit with the reason, and the guard is what stops it")
    func holdRefusesTheEdit() throws {
        var keeper = try opened()
        keeper.perform(.reload)
        #expect(keeper.nextStep() == .read)
        keeper.finish(.read(nil))
        #expect(keeper.warning == .vanished)
        let before = held(keeper)

        let start = CanvasAgentEdit.begin([fixture.move(fixture.boxID, revision: 0)], on: &keeper)

        guard case .refused(let sentence) = start else {
            Issue.record("expected a refusal, got \(start)")
            return
        }
        #expect(sentence.contains("no longer on disk"))
        #expect(held(keeper) == before)
        #expect(keeper.undoDepth == 0)
    }

    @Test("a corrupt or newer document is refused with its reason")
    func unreadableDocumentsAreRefused() {
        var corrupt = CanvasDocumentKeeper(opening: .read(Data("nope".utf8)))
        var newer = CanvasDocumentKeeper(opening: .read(Data(#"{"version": 999}"#.utf8)))

        let first = CanvasAgentEdit.begin([.reorder(fixture.boxID, toIndex: 0)], on: &corrupt)
        let second = CanvasAgentEdit.begin([.reorder(fixture.boxID, toIndex: 0)], on: &newer)

        guard case .refused(let one) = first, case .refused(let two) = second else {
            Issue.record("expected two refusals")
            return
        }
        #expect(one.contains("cannot be edited"))
        #expect(two.contains("999"))
    }

    @Test("the answer says saved once the file took the change")
    func savedWhenTheFileLands() throws {
        var keeper = try opened()
        let edit = try #require(pending(CanvasAgentEdit.begin([fixture.move(fixture.boxID, revision: 0)], on: &keeper)))
        let step = keeper.nextStep()
        guard case .save(let data, _) = step else {
            Issue.record("no save step")
            return
        }
        keeper.finish(.written(data))

        #expect(CanvasAgentEdit.conclude(edit, on: keeper).disk == .saved)
    }

    @Test("a write that failed is reported as not saved")
    func notSavedWhenTheWriteFails() throws {
        var keeper = try opened()
        let edit = try #require(pending(CanvasAgentEdit.begin([fixture.move(fixture.boxID, revision: 0)], on: &keeper)))
        #expect(keeper.nextStep() != nil)
        keeper.finish(.writeFailed("The disk is full."))

        #expect(CanvasAgentEdit.conclude(edit, on: keeper).disk == .notSaved("This canvas is not saved"))
    }

    @Test("a reload that replaced the document while it was being saved is reported as replaced")
    func replacedWhenTheFileChangedUnderneath() throws {
        var keeper = try opened()
        let edit = try #require(pending(CanvasAgentEdit.begin([fixture.move(fixture.boxID, revision: 0)], on: &keeper)))
        #expect(keeper.nextStep() != nil)
        keeper.finish(.outsideChange)
        #expect(keeper.nextStep() == .read)
        var outside = fixture.session().document
        outside.frames[0].name = "From git"
        keeper.finish(.read(try CanvasDocumentCodec.encode(outside)))
        guard case .backup = keeper.nextStep() else {
            Issue.record("the reload did not go through a backup")
            return
        }
        keeper.finish(.backedUp("/work/deck.udcanvas.backup-1"))

        #expect(CanvasAgentEdit.conclude(edit, on: keeper).disk == .replaced)
    }

    @Test("an element the owner is typing in survives an agent delete, and the answer shows what is really there")
    func draftRescueIsReported() throws {
        var keeper = try opened()
        let original = try #require(held(keeper)?.elements.first { $0.id == fixture.titleID }?.text)
        keeper.setDraft(CanvasTextDraft(elementID: fixture.titleID, original: original, text: original, measuredHeight: 20))

        let start = CanvasAgentEdit.begin([.deleteElement(fixture.titleID, expectedRevision: 2)], on: &keeper)
        let changes = try #require(pending(start)).changes

        #expect(held(keeper)?.elements.contains { $0.id == fixture.titleID } == true)
        #expect(changes.deletedElements.isEmpty)
    }
}
