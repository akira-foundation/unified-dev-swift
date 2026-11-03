import Foundation

public enum CanvasCommentDelivery {
    public enum Decision: Sendable, Equatable {
        case send(String)
        case drop
    }

    public static func delivery(
        for comment: CanvasComment, path: String, in document: CanvasDocument, to session: SessionID, createdAt: Date
    ) -> Delivery {
        Delivery(
            targetSessionID: session,
            kind: .canvasComment,
            body: CanvasCommentFlow.message(for: comment, path: path, in: document),
            createdAt: createdAt,
            canvasDocumentPath: path
        )
    }

    public static func documentPath(of delivery: Delivery, worktree: String) -> String? {
        guard let path = delivery.canvasDocumentPath,
              case .file(let absolute, _) = CanvasFile.contained(path: path, worktree: worktree),
              CanvasDocumentFile.isDocument(path: absolute) else { return nil }
        return absolute
    }

    public static func decide(_ delivery: Delivery, in document: CanvasDocumentDecoding?) -> Decision {
        guard delivery.state == .pending, let path = delivery.canvasDocumentPath,
              case .document(let held) = document,
              let comment = held.comments.first(where: { $0.deliveryID == delivery.id }),
              CanvasCommentFlow.owesAnAnswer(comment.state) else { return .drop }
        return .send(CanvasCommentFlow.message(for: comment, path: path, in: held))
    }

    public static func assigned(
        _ id: CanvasCommentID, to delivery: DeliveryID, in document: CanvasDocument
    ) -> CanvasDocument {
        var changed = document
        for index in changed.comments.indices where changed.comments[index].id == id {
            changed.comments[index].deliveryID = delivery
            changed.comments[index].state = .queued
        }
        return changed
    }

    public static func started(_ delivery: DeliveryID, in document: CanvasDocument) -> CanvasDocument {
        guard let comment = document.comments.first(where: { $0.deliveryID == delivery }) else { return document }
        return CanvasCommentFlow.started(comment.id, in: document)
    }

    public static func notSent(_ delivery: DeliveryID, stillQueued: Bool, in document: CanvasDocument) -> CanvasDocument {
        var changed = document
        for index in changed.comments.indices
        where changed.comments[index].deliveryID == delivery && CanvasCommentFlow.owesAnAnswer(changed.comments[index].state) {
            changed.comments[index].state = stillQueued ? .queued : .unanswered
        }
        return changed
    }

    public static func awaitingChat(in document: CanvasDocument) -> [CanvasComment] {
        document.comments.filter { $0.state == .queued && $0.deliveryID == nil }
    }

    public static func deliveriesToCheck(in document: CanvasDocument) -> Set<DeliveryID> {
        Set(document.comments.filter { $0.state == .queued }.compactMap(\.deliveryID))
    }

    public static func settled(
        _ document: CanvasDocument, inFlight: Set<DeliveryID>, checked: Set<DeliveryID>, live: Set<DeliveryID>
    ) -> CanvasDocument {
        var changed = document
        for index in changed.comments.indices {
            let comment = changed.comments[index]
            let ended: Bool
            switch comment.state {
            case .working:
                ended = comment.deliveryID.map { !inFlight.contains($0) } ?? true
            case .queued:
                ended = comment.deliveryID.map { checked.contains($0) && !live.contains($0) } ?? false
            case .resolved, .declined, .unanswered:
                ended = false
            }
            if ended { changed.comments[index].state = .unanswered }
        }
        return changed
    }
}
