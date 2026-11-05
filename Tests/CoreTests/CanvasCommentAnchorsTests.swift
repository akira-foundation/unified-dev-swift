import Foundation
import Testing
@testable import Core

@Suite("A comment's anchor follows what it points at")
struct CanvasCommentAnchorsTests {
    private let frameID = CanvasFrameID("f1")
    private let otherID = CanvasFrameID("f2")
    private let boxID = CanvasElementID("box")
    private let start = CanvasPoint(x: 150, y: 160)

    private func base(comment: CanvasComment) -> CanvasDocument {
        let frame = CanvasFrame(id: frameID, name: "One", rect: CanvasRect(x: 0, y: 0, width: 1_000, height: 1_000))
        let other = CanvasFrame(id: otherID, name: "Two", rect: CanvasRect(x: 2_000, y: 0, width: 1_000, height: 1_000))
        let box = CanvasElement(
            id: boxID, frameID: frameID, rect: CanvasRect(x: 100, y: 100, width: 200, height: 200),
            kind: .shape(CanvasShape(kind: .rectangle))
        )
        return CanvasDocument(frames: [frame, other], elements: [box], comments: [comment])
    }

    private func comment(frame: CanvasFrameID? = nil, element: CanvasElementID? = nil) -> CanvasComment {
        CanvasComment(
            id: CanvasCommentID("c"), anchor: start, frameID: frame, elementID: element, text: "Here",
            createdAt: Date(timeIntervalSince1970: 0)
        )
    }

    private func anchor(in document: CanvasDocument) throws -> CanvasPoint {
        try #require(document.comments.first).anchor
    }

    private func moved(_ document: CanvasDocument, box rect: CanvasRect? = nil, frame frameRect: CanvasRect? = nil) -> CanvasDocument {
        var changed = document
        if let rect { changed.elements[0].rect = rect }
        if let frameRect { changed.frames[0].rect = frameRect }
        return changed
    }

    @Test func aMovedElementTakesItsCommentWithIt() throws {
        let old = base(comment: comment(frame: frameID, element: boxID))
        let new = moved(old, box: CanvasRect(x: 130, y: 90, width: 200, height: 200))
        let followed = CanvasCommentAnchors.following(from: old, to: new)
        #expect(try anchor(in: followed) == CanvasPoint(x: 180, y: 150))
    }

    @Test func aMovedFrameTakesACommentOnTheFrameWithIt() throws {
        let old = base(comment: comment(frame: frameID))
        let new = moved(old, frame: CanvasRect(x: 40, y: 70, width: 1_000, height: 1_000))
        let followed = CanvasCommentAnchors.following(from: old, to: new)
        #expect(try anchor(in: followed) == CanvasPoint(x: 190, y: 230))
    }

    @Test func aMovedFrameShiftsACommentOnAnElementInsideItOnce() throws {
        let old = base(comment: comment(frame: frameID, element: boxID))
        let new = moved(old, frame: CanvasRect(x: 40, y: 70, width: 1_000, height: 1_000))
        let followed = CanvasCommentAnchors.following(from: old, to: new)
        #expect(try anchor(in: followed) == CanvasPoint(x: 190, y: 230))
    }

    @Test func anElementMovedWithItsFrameAddsBothMovesOnce() throws {
        let old = base(comment: comment(frame: frameID, element: boxID))
        let new = moved(
            old, box: CanvasRect(x: 110, y: 100, width: 200, height: 200), frame: CanvasRect(x: 40, y: 70, width: 1_000, height: 1_000)
        )
        let followed = CanvasCommentAnchors.following(from: old, to: new)
        #expect(try anchor(in: followed) == CanvasPoint(x: 200, y: 230))
    }

    @Test func anElementMovedToAnotherFrameIsFollowedInCanvasSpace() throws {
        let old = base(comment: comment(frame: frameID, element: boxID))
        var new = old
        new.elements[0].frameID = otherID
        let followed = CanvasCommentAnchors.following(from: old, to: new)
        #expect(try anchor(in: followed) == CanvasPoint(x: 2_150, y: 160))
    }

    @Test func aMovedElementLeavesACommentOnTheFrameAlone() throws {
        let old = base(comment: comment(frame: frameID))
        let new = moved(old, box: CanvasRect(x: 500, y: 500, width: 200, height: 200))
        #expect(try anchor(in: CanvasCommentAnchors.following(from: old, to: new)) == start)
    }

    @Test func aResizeThatKeepsTheOriginMovesNothing() throws {
        let old = base(comment: comment(frame: frameID, element: boxID))
        let new = moved(old, box: CanvasRect(x: 100, y: 100, width: 900, height: 40))
        #expect(try anchor(in: CanvasCommentAnchors.following(from: old, to: new)) == start)
    }

    @Test func aCommentWithNothingToFollowStaysWhereItIs() throws {
        let old = base(comment: comment())
        let new = moved(old, box: CanvasRect(x: 500, y: 500, width: 200, height: 200), frame: CanvasRect(x: 9, y: 9, width: 1_000, height: 1_000))
        #expect(try anchor(in: CanvasCommentAnchors.following(from: old, to: new)) == start)
    }

    @Test func aCommentWhoseElementIsGoneFollowsItsFrame() throws {
        let old = base(comment: comment(frame: frameID, element: boxID))
        var new = moved(old, frame: CanvasRect(x: 5, y: 6, width: 1_000, height: 1_000))
        new.elements = []
        #expect(try anchor(in: CanvasCommentAnchors.following(from: old, to: new)) == CanvasPoint(x: 155, y: 166))
    }

    @Test func applyByEitherAuthorMovesTheAnchor() throws {
        for author in [CanvasAuthor.owner, .agent] {
            var keeper = CanvasDocumentKeeper(opening: .read(try CanvasDocumentCodec.encode(base(comment: comment(frame: frameID, element: boxID)))))
            let patch = CanvasElementPatch(rect: CanvasRect(x: 130, y: 100, width: 200, height: 200))
            _ = keeper.apply([.updateElement(boxID, expectedRevision: 0, patch)], by: author)
            guard case .document(let held) = keeper.document else {
                Issue.record("no document")
                return
            }
            #expect(try anchor(in: held) == CanvasPoint(x: 180, y: 160))
        }
    }

    @Test func undoAndRedoTakeTheAnchorBackAndForth() throws {
        var keeper = CanvasDocumentKeeper(opening: .read(try CanvasDocumentCodec.encode(base(comment: comment(frame: frameID)))))
        let patch = CanvasFramePatch(rect: CanvasRect(x: 40, y: 0, width: 1_000, height: 1_000))
        _ = keeper.apply([.updateFrame(frameID, expectedRevision: nil, patch)], by: .owner)
        let revisionAfterMove = try frameRevision(keeper)

        let undone = keeper.undo()
        #expect(undone)
        guard case .document(let afterUndo) = keeper.document else {
            Issue.record("no document")
            return
        }
        #expect(try anchor(in: afterUndo) == start)

        let redone = keeper.redo()
        #expect(redone)
        guard case .document(let afterRedo) = keeper.document else {
            Issue.record("no document")
            return
        }
        #expect(try anchor(in: afterRedo) == CanvasPoint(x: 190, y: 160))
        #expect(try frameRevision(keeper) >= revisionAfterMove)
    }

    @Test func followingIsNotAnUndoStepAndRaisesNoRevision() throws {
        let old = base(comment: comment(frame: frameID, element: boxID))
        let new = moved(old, box: CanvasRect(x: 130, y: 100, width: 200, height: 200))
        let followed = CanvasCommentAnchors.following(from: old, to: new)
        #expect(followed.elements == new.elements)
        #expect(followed.frames == new.frames)

        var keeper = CanvasDocumentKeeper(opening: .read(try CanvasDocumentCodec.encode(old)))
        let patch = CanvasElementPatch(rect: CanvasRect(x: 130, y: 100, width: 200, height: 200))
        _ = keeper.apply([.updateElement(boxID, expectedRevision: nil, patch)], by: .owner)
        #expect(keeper.undoDepth == 1)
        #expect(keeper.recordedSteps == 1)
    }

    @Test func undoingADeleteAndThenTheMoveTakesTheAnchorHome() throws {
        var keeper = CanvasDocumentKeeper(opening: .read(try CanvasDocumentCodec.encode(base(comment: comment(frame: frameID, element: boxID)))))
        let patch = CanvasElementPatch(rect: CanvasRect(x: 130, y: 100, width: 200, height: 200))
        _ = keeper.apply([.updateElement(boxID, expectedRevision: nil, patch)], by: .owner)
        _ = keeper.apply([.deleteElement(boxID, expectedRevision: nil)], by: .owner)
        guard case .document(let deleted) = keeper.document else { throw CanvasNoDocument() }
        #expect(try #require(deleted.comments.first).elementID == nil)
        #expect(try anchor(in: deleted) == CanvasPoint(x: 180, y: 160))

        let restoredElement = keeper.undo()
        #expect(restoredElement)
        guard case .document(let back) = keeper.document else { throw CanvasNoDocument() }
        #expect(try #require(back.comments.first).elementID == nil)

        let undidMove = keeper.undo()
        #expect(undidMove)
        guard case .document(let home) = keeper.document else { throw CanvasNoDocument() }
        #expect(try anchor(in: home) == start)

        let redidMove = keeper.redo()
        #expect(redidMove)
        let redidDelete = keeper.redo()
        #expect(redidDelete)
        guard case .document(let again) = keeper.document else { throw CanvasNoDocument() }
        #expect(try #require(again.comments.first).elementID == nil)
        #expect(try anchor(in: again) == CanvasPoint(x: 180, y: 160))
    }

    @Test func undoingAFrameDeleteAndThenItsMoveTakesTheAnchorHome() throws {
        var keeper = CanvasDocumentKeeper(opening: .read(try CanvasDocumentCodec.encode(base(comment: comment(frame: frameID)))))
        let patch = CanvasFramePatch(rect: CanvasRect(x: 40, y: 0, width: 1_000, height: 1_000))
        _ = keeper.apply([.updateFrame(frameID, expectedRevision: nil, patch)], by: .owner)
        _ = keeper.apply([.deleteFrame(frameID, expectedRevision: nil)], by: .owner)
        let restoredFrame = keeper.undo()
        let undidMove = keeper.undo()
        #expect(restoredFrame)
        #expect(undidMove)
        guard case .document(let home) = keeper.document else { throw CanvasNoDocument() }
        #expect(try anchor(in: home) == start)
        #expect(try #require(home.comments.first).frameID == nil)
    }

    @Test func aDeletedElementThatStaysDeletedLeavesTheAnchorOnItsFrame() throws {
        var keeper = CanvasDocumentKeeper(opening: .read(try CanvasDocumentCodec.encode(base(comment: comment(frame: frameID, element: boxID)))))
        _ = keeper.apply([.deleteElement(boxID, expectedRevision: nil)], by: .owner)
        let patch = CanvasFramePatch(rect: CanvasRect(x: 40, y: 0, width: 1_000, height: 1_000))
        _ = keeper.apply([.updateFrame(frameID, expectedRevision: nil, patch)], by: .owner)
        guard case .document(let held) = keeper.document else { throw CanvasNoDocument() }
        #expect(try anchor(in: held) == CanvasPoint(x: 190, y: 160))
    }

    @Test func aCommentLeftAfterTheStepKeepsItsLinksThroughAnUndo() throws {
        let old = base(comment: comment(frame: frameID))
        var keeper = CanvasDocumentKeeper(opening: .read(try CanvasDocumentCodec.encode(old)))
        let patch = CanvasElementPatch(rect: CanvasRect(x: 130, y: 100, width: 200, height: 200))
        _ = keeper.apply([.updateElement(boxID, expectedRevision: nil, patch)], by: .owner)
        let later = CanvasComment(
            id: CanvasCommentID("later"), anchor: start, frameID: frameID, elementID: boxID, text: "Later",
            createdAt: Date(timeIntervalSince1970: 1)
        )
        keeper.changeComments { current in
            var changed = current
            changed.comments.append(later)
            return changed
        }
        let undone = keeper.undo()
        #expect(undone)
        guard case .document(let held) = keeper.document else { throw CanvasNoDocument() }
        let kept = try #require(held.comments.first { $0.id == later.id })
        #expect(kept.elementID == boxID)
        #expect(kept.anchor == CanvasPoint(x: 120, y: 160))
    }

    @Test func anEditAfterAnUndoStillFollowsTheLinkTheHistoryRemembers() throws {
        var keeper = CanvasDocumentKeeper(opening: .read(try CanvasDocumentCodec.encode(base(comment: comment(frame: frameID, element: boxID)))))
        _ = keeper.apply([.deleteElement(boxID, expectedRevision: nil)], by: .owner)
        let restored = keeper.undo()
        #expect(restored)
        guard case .document(let back) = keeper.document else { throw CanvasNoDocument() }
        #expect(try #require(back.comments.first).elementID == nil)

        let patch = CanvasElementPatch(rect: CanvasRect(x: 130, y: 100, width: 200, height: 200))
        _ = keeper.apply([.updateElement(boxID, expectedRevision: nil, patch)], by: .owner)
        guard case .document(let moved) = keeper.document else { throw CanvasNoDocument() }
        #expect(try anchor(in: moved) == CanvasPoint(x: 180, y: 160))
    }

    private func frameRevision(_ keeper: CanvasDocumentKeeper) throws -> Int {
        guard case .document(let held) = keeper.document else { throw CanvasNoDocument() }
        return try #require(held.frames.first).revision
    }
}

private struct CanvasNoDocument: Error {}
