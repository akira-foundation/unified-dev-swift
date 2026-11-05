import Foundation
import Testing
@testable import Core

@Suite("Deleting what is selected")
struct CanvasSelectionDeleteTests {
    private static let one = CanvasFrame(id: CanvasFrameID("one"), name: "One", rect: CanvasRect(x: 0, y: 0, width: 500, height: 500))
    private static let box = CanvasElement(
        id: CanvasElementID("box"), frameID: one.id, rect: CanvasRect(x: 10, y: 20, width: 50, height: 50), kind: .shape(CanvasShape(kind: .rectangle))
    )
    private static let spare = CanvasElement(
        id: CanvasElementID("spare"), frameID: one.id, rect: CanvasRect(x: 90, y: 20, width: 50, height: 50), kind: .shape(CanvasShape(kind: .rectangle))
    )
    private static let comment = CanvasComment(
        id: CanvasCommentID("c"), anchor: CanvasPoint(x: 20, y: 30), frameID: one.id, elementID: box.id, text: "t",
        state: .working, createdAt: Date(timeIntervalSince1970: 0)
    )
    private let document = CanvasDocument(frames: [one], elements: [box, spare], comments: [comment])

    private func keeper() throws -> CanvasDocumentKeeper {
        CanvasDocumentKeeper(opening: .read(try CanvasDocumentCodec.encode(document)))
    }

    private func held(_ keeper: CanvasDocumentKeeper) throws -> CanvasDocument {
        guard case .document(let document) = keeper.document else { throw CocoaError(.coderReadCorrupt) }
        return document
    }

    @Test func deletingElementsIsOneUndoStep() throws {
        var keeper = try keeper()
        let operations = CanvasSelection(elements: [Self.box.id, Self.spare.id]).deleteOperations(in: document, isEditing: false, isPlaying: false)
        _ = keeper.apply(operations, by: .owner)
        #expect(keeper.recordedSteps == 1)
        #expect(try held(keeper).elements.isEmpty)
        let undone = keeper.undo()
        #expect(undone)
        #expect(try held(keeper).elements.map(\.id) == [Self.box.id, Self.spare.id])
    }

    @Test func deletingAFrameTakesItsElementsInOneUndoStep() throws {
        var keeper = try keeper()
        _ = keeper.apply(CanvasSelection(frame: Self.one.id).deleteOperations(in: document, isEditing: false, isPlaying: false), by: .owner)
        #expect(keeper.recordedSteps == 1)
        #expect(try held(keeper).frames.isEmpty && held(keeper).elements.isEmpty)
        let undone = keeper.undo()
        #expect(undone)
        #expect(try held(keeper).frames.count == 1 && held(keeper).elements.count == 2)
    }

    @Test func aCommentOnADeletedFrameStaysWhereItWasAndKeepsItsState() throws {
        var keeper = try keeper()
        _ = keeper.apply(CanvasSelection(frame: Self.one.id).deleteOperations(in: document, isEditing: false, isPlaying: false), by: .owner)
        let comment = try #require(try held(keeper).comments.first)
        #expect(comment.state == .working)
        #expect(comment.frameID == nil && comment.elementID == nil)
        #expect(comment.anchor == Self.comment.anchor)
    }

    @Test func nothingIsDeletedWhileTextIsBeingEditedOrTheFramesArePlaying() {
        let selection = CanvasSelection(elements: [Self.box.id])
        #expect(selection.deleteOperations(in: document, isEditing: true, isPlaying: false).isEmpty)
        #expect(selection.deleteOperations(in: document, isEditing: false, isPlaying: true).isEmpty)
        #expect(selection.canDelete(in: document, isEditing: false, isPlaying: false))
        #expect(!selection.canDelete(in: document, isEditing: true, isPlaying: false))
        #expect(!selection.canDelete(in: document, isEditing: false, isPlaying: true))
    }

    @Test func nothingSelectedOrAlreadyGoneDeletesNothing() {
        #expect(CanvasSelection().deleteOperations(in: document, isEditing: false, isPlaying: false).isEmpty)
        #expect(!CanvasSelection().canDelete(in: document, isEditing: false, isPlaying: false))
        let gone = CanvasSelection(elements: [CanvasElementID("gone")])
        #expect(gone.deleteOperations(in: document, isEditing: false, isPlaying: false).isEmpty)
        #expect(CanvasSelection(frame: CanvasFrameID("gone")).deleteOperations(in: document, isEditing: false, isPlaying: false).isEmpty)
    }

    @Test(arguments: [(UInt16(51), true), (117, true), (53, false), (0, false), (36, false)])
    func onlyTheTwoDeleteKeysDelete(keyCode: UInt16, deletes: Bool) {
        #expect(CanvasSelection.isDeleteKey(keyCode) == deletes)
    }
}
