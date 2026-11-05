import Foundation
import Core

struct CanvasCommentCourier {
    let send: @MainActor (CanvasCommentID) async -> CanvasCommentSending
    let cancel: @MainActor (_ delivery: DeliveryID, _ wakesTheRest: Bool) async -> Bool
    let wait: @MainActor (CanvasComment) -> CanvasCommentWait?
}

extension CanvasDocumentModel {
    func canvasCommentDispatch(of delivery: Delivery) -> CanvasCommentDelivery.Decision {
        CanvasCommentDelivery.decide(delivery, in: keeper.document)
    }

    func canvasCommentStarted(deliveryID: DeliveryID) {
        changeComments { CanvasCommentDelivery.started(deliveryID, in: $0) }
    }

    func canvasCommentTurnEnded(deliveryID: DeliveryID) {
        changeComments { CanvasCommentFlow.turnEnded(delivery: deliveryID, in: $0) }
    }

    func canvasCommentNotSent(deliveryID: DeliveryID, stillQueued: Bool) {
        changeComments { CanvasCommentDelivery.notSent(deliveryID, stillQueued: stillQueued, in: $0) }
    }

    var commentsAwaitingChat: [CanvasComment] {
        guard case .document(let held) = document else { return [] }
        return CanvasCommentDelivery.awaitingChat(in: held)
    }

    var commentMarks: [CanvasComment] {
        guard case .document(let held) = document else { return [] }
        return CanvasCommentBoard.marks(in: held, confirmed: confirmedCommentDeliveries)
    }

    var listedComments: [CanvasComment] {
        guard case .document(let held) = document else { return [] }
        return CanvasCommentBoard.listed(in: held)
    }

    var unreadDeclinedComments: [CanvasComment] {
        guard case .document(let held) = document else { return [] }
        return CanvasCommentBoard.unreadDeclined(in: held, seen: seenDeclinedComments)
    }

    func commentStatus(of comment: CanvasComment) -> CanvasCommentStatus {
        CanvasCommentBoard.status(of: comment, wait: commentCourier?.wait(comment))
    }

    @discardableResult
    func addComment(at point: CanvasPoint, text: String) async -> CanvasCommentID? {
        guard case .document(let held) = document,
              let comment = CanvasCommentFlow.placed(text: text, at: point, in: held, createdAt: Date()) else { return nil }
        changeComments { current in
            var changed = current
            changed.comments.append(comment)
            return changed
        }
        await send(comment.id)
        return comment.id
    }

    @discardableResult
    func editQueued(_ id: CanvasCommentID, text: String) async -> Bool {
        guard let comment = comment(id), CanvasCommentBoard.canEdit(comment),
              case .document(let held) = document,
              CanvasCommentFlow.edited(id, text: text, in: held) != held else { return false }
        if let delivery = comment.deliveryID, await commentCourier?.cancel(delivery, false) == false { return false }
        changeComments { CanvasCommentFlow.edited(id, text: text, in: $0) }
        await send(id)
        return true
    }

    @discardableResult
    func deleteQueued(_ id: CanvasCommentID) async -> Bool {
        guard let comment = comment(id), CanvasCommentBoard.canDelete(comment) else { return false }
        if comment.state == .queued, let delivery = comment.deliveryID,
           await commentCourier?.cancel(delivery, true) == false {
            return false
        }
        changeComments { CanvasCommentFlow.removed(id, in: $0) }
        return true
    }

    func resend(_ id: CanvasCommentID) async {
        guard let comment = comment(id), CanvasCommentBoard.canResend(comment) else { return }
        await send(id)
    }

    private func send(_ id: CanvasCommentID) async {
        guard await commentCourier?.send(id) == .awaitingChat else { return }
        changeComments { CanvasCommentDelivery.awaitingChatAgain(id, in: $0) }
    }

    private func comment(_ id: CanvasCommentID) -> CanvasComment? {
        guard case .document(let held) = document else { return nil }
        return held.comments.first { $0.id == id }
    }
}
