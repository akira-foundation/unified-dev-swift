import Foundation
import Core

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
}
