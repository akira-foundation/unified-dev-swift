import Foundation
import Testing
@testable import Core

@Suite("What holds a chat still after a stop or a rewind")
struct ChatStopTests {
    private func delivery(_ id: String, comment: Bool) -> Delivery {
        Delivery(
            id: DeliveryID(id), targetSessionID: SessionID("s"), kind: comment ? .canvasComment : .owner, body: "b",
            canvasDocumentPath: comment ? "/w/d.udcanvas" : nil
        )
    }

    private var comment: Delivery { delivery("c", comment: true) }
    private var message: Delivery { delivery("m", comment: false) }

    @Test func aRewindInAChatNobodyStoppedIsNotTheOwnersStop() {
        #expect(ChatStop.notStopped.afterRewind == .byRewind)
    }

    @Test func aRewindDoesNotForgiveTheOwnersOwnStop() {
        #expect(ChatStop.byOwner.afterRewind == .byOwner)
    }

    @Test func aRewindHoldsOrdinaryMessagesButNotComments() {
        #expect(ChatStop.byRewind.holdsMessages)
        #expect(!ChatStop.byRewind.holdsCanvasComments)
        #expect(ChatStop.byOwner.holdsMessages)
        #expect(ChatStop.byOwner.holdsCanvasComments)
        #expect(!ChatStop.notStopped.holdsMessages)
    }

    @Test func commentsAloneAfterARewindGoAndTheHoldEnds() {
        #expect(ChatStop.byRewind.releasedForCanvasComments(pending: [comment]) == .notStopped)
    }

    @Test func aMessageInTheQueueKeepsTheRewindsHold() {
        #expect(ChatStop.byRewind.releasedForCanvasComments(pending: [comment, message]) == nil)
        #expect(ChatStop.byRewind.releasedForCanvasComments(pending: [message, comment]) == nil)
        #expect(ChatStop.byRewind.releasedForCanvasComments(pending: []) == nil)
    }

    @Test func theOwnersStopKeepsCommentsBack() {
        #expect(ChatStop.byOwner.releasedForCanvasComments(pending: [comment]) == nil)
    }

    @Test func aChatNobodyStoppedSendsCommentsAlone() {
        #expect(ChatStop.notStopped.releasedForCanvasComments(pending: [comment]) == .notStopped)
        #expect(ChatStop.notStopped.releasedForCanvasComments(pending: [comment, message]) == nil)
    }

    @Test func theOwnerIsNotToldHeStoppedAChatARewindHeld() {
        let held = CanvasComment(
            anchor: CanvasPoint(x: 0, y: 0), text: "t", deliveryID: DeliveryID("c"), createdAt: Date(timeIntervalSince1970: 0)
        )
        let alone = CanvasCommentDelivery.wait(of: held, behind: [comment], chat: CanvasCommentChat(heldAfterRewind: true))
        let behindAMessage = CanvasCommentDelivery.wait(of: held, behind: [message, comment], chat: CanvasCommentChat(heldAfterRewind: true))

        #expect(alone == .nextInLine)
        #expect(behindAMessage == .messageHeldAfterRewind)
        #expect(CanvasCommentBoard.status(of: held, wait: .messageHeldAfterRewind).needsOwner)
        #expect(!CanvasCommentBoard.status(of: held, wait: .messageHeldAfterRewind).detail.contains("You stopped"))
    }

    @Test func theOwnerIsNotToldToDeleteARequestThatIsNotDrawn() {
        let held = CanvasComment(
            anchor: CanvasPoint(x: 0, y: 0), text: "t", deliveryID: DeliveryID("c"), createdAt: Date(timeIntervalSince1970: 0)
        )
        let request = AppRequest.delivery(to: SessionID("s"), text: "The code block ran.", interactionMode: nil)
        var stuck = request
        stuck.state = .uncertain

        let behindARequest = CanvasCommentDelivery.wait(of: held, behind: [request, comment], chat: CanvasCommentChat(heldAfterRewind: true))
        let behindAStuckRequest = CanvasCommentDelivery.wait(of: held, behind: [stuck, comment], chat: CanvasCommentChat(heldAfterRewind: true))
        let status = CanvasCommentBoard.status(of: held, wait: behindARequest)

        #expect(behindARequest == .requestHeldAfterRewind)
        #expect(behindAStuckRequest == .messageHeldAfterRewind)
        #expect(status.needsOwner)
        #expect(!status.detail.contains("delete"))
    }
}
