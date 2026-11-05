import Foundation
import Testing
@testable import Core

@Suite("Moving a frame")
struct CanvasFrameMoveTests {
    private static let one = CanvasFrame(id: CanvasFrameID("one"), name: "One", rect: CanvasRect(x: 0, y: 0, width: 500, height: 500))
    private static let two = CanvasFrame(id: CanvasFrameID("two"), name: "Two", rect: CanvasRect(x: 600, y: 0, width: 500, height: 500))
    private static let three = CanvasFrame(id: CanvasFrameID("three"), name: "Three", rect: CanvasRect(x: 1_200, y: 40, width: 500, height: 500))
    private static let box = CanvasElement(
        id: CanvasElementID("box"), frameID: one.id, rect: CanvasRect(x: 10, y: 20, width: 50, height: 50), kind: .shape(CanvasShape(kind: .rectangle))
    )
    private let document = CanvasDocument(frames: [one, two, three], elements: [box])

    @Test func aDragFarFromAnythingFollowsThePointer() throws {
        let plan = try #require(CanvasMove.plan(movingFrame: Self.one.id, by: CanvasPoint(x: 37, y: 913), in: document))
        #expect(plan.rect.origin == CanvasPoint(x: 37, y: 913))
        #expect(plan.rect.size == Self.one.rect.size)
        #expect(plan.guides.isEmpty)
    }

    @Test func aDragNearAnotherFrameSnapsToIt() throws {
        let plan = try #require(CanvasMove.plan(movingFrame: Self.three.id, by: CanvasPoint(x: -500, y: -37), in: document))
        #expect(plan.rect.origin.y == 0)
        #expect(plan.rect.origin.x == 700)
        #expect(!plan.guides.isEmpty)
    }

    @Test func aFrameDoesNotSnapToItself() throws {
        let plan = try #require(CanvasMove.plan(movingFrame: Self.one.id, by: CanvasPoint(x: 2, y: 1_000), in: document))
        #expect(plan.rect.origin.x == 2)
    }

    @Test func anUnknownFrameHasNoPlan() {
        #expect(CanvasMove.plan(movingFrame: CanvasFrameID("gone"), by: CanvasPoint(x: 1, y: 1), in: document) == nil)
    }

    @Test func movingAFrameIsOneOperationAndItsElementsGoWithIt() throws {
        let target = CanvasRect(x: 300, y: 400, width: 500, height: 500)
        let operations = CanvasMove.operations(movingFrame: Self.one.id, to: target, in: document)
        #expect(operations.count == 1)
        var session = CanvasDocumentSession(document: document)
        _ = session.apply(operations, by: .owner)
        let moved = try #require(session.document.elements.first)
        #expect(session.document.frames.first?.rect == target)
        #expect(moved.rect == Self.box.rect)
        #expect(CanvasHitTest.absoluteRect(of: moved, in: session.document).origin == CanvasPoint(x: 310, y: 420))
    }

    @Test func stayingPutIsNoOperation() {
        #expect(CanvasMove.operations(movingFrame: Self.one.id, to: Self.one.rect, in: document).isEmpty)
    }

    @Test func draggingAFramePastAnotherReordersTheSlides() {
        var session = CanvasDocumentSession(document: document)
        #expect(CanvasPlayback(frames: session.document.frames).frames.map(\.id) == [Self.one.id, Self.two.id, Self.three.id])
        let target = CanvasRect(x: 900, y: 0, width: 500, height: 500)
        _ = session.apply(CanvasMove.operations(movingFrame: Self.one.id, to: target, in: document), by: .owner)
        #expect(CanvasPlayback(frames: session.document.frames).frames.map(\.id) == [Self.two.id, Self.one.id, Self.three.id])
    }

    @Test func aMoveIsOneUndoStepAndACommentOnTheFrameFollows() throws {
        let comment = CanvasComment(
            id: CanvasCommentID("c"), anchor: CanvasPoint(x: 20, y: 30), frameID: Self.one.id, text: "t", createdAt: Date(timeIntervalSince1970: 0)
        )
        var withComment = document
        withComment.comments = [comment]
        var keeper = CanvasDocumentKeeper(opening: .read(try CanvasDocumentCodec.encode(withComment)))
        let target = CanvasRect(x: 300, y: 400, width: 500, height: 500)
        _ = keeper.apply(CanvasMove.operations(movingFrame: Self.one.id, to: target, in: withComment), by: .owner)
        #expect(keeper.recordedSteps == 1)
        guard case .document(let moved) = keeper.document else {
            Issue.record("no document")
            return
        }
        #expect(moved.comments.first?.anchor == CanvasPoint(x: 320, y: 430))
        let undone = keeper.undo()
        #expect(undone)
        guard case .document(let back) = keeper.document else {
            Issue.record("no document")
            return
        }
        #expect(back.frames.first?.rect == Self.one.rect)
    }
}
