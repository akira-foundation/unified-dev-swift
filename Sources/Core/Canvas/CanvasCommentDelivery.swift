import Foundation

public enum CanvasCommentWait: Sendable, Equatable {
    case cameWithFile
    case archiving
    case documentHeld
    case noChat
    case terminalChat
    case rewindInterrupted
    case stoppedByHand
    case messageHeldAfterRewind
    case draftBeingEdited
    case held(DeliveryHold)
    case savingTurn
    case messageAhead
    case commentAhead
    case nextInLine
}

public struct CanvasCommentPlace: Sendable, Equatable {
    public var addedThisRun: CanvasCommentsAddedThisRun
    public var archiving: Bool
    public var documentHeld: Bool

    public init(addedThisRun: CanvasCommentsAddedThisRun = CanvasCommentsAddedThisRun(), archiving: Bool = false, documentHeld: Bool = false) {
        self.addedThisRun = addedThisRun
        self.archiving = archiving
        self.documentHeld = documentHeld
    }
}

public struct CanvasCommentChat: Sendable, Equatable {
    public var stoppedByHand: Bool
    public var heldAfterRewind: Bool
    public var draftBeingEdited: Bool
    public var hold: DeliveryHold
    public var savingTurn: Bool
    public var rewindInterrupted: Bool
    public var runsInTerminal: Bool

    public init(
        stoppedByHand: Bool = false,
        heldAfterRewind: Bool = false,
        draftBeingEdited: Bool = false,
        hold: DeliveryHold = .none,
        savingTurn: Bool = false,
        rewindInterrupted: Bool = false,
        runsInTerminal: Bool = false
    ) {
        self.stoppedByHand = stoppedByHand
        self.heldAfterRewind = heldAfterRewind
        self.draftBeingEdited = draftBeingEdited
        self.hold = hold
        self.savingTurn = savingTurn
        self.rewindInterrupted = rewindInterrupted
        self.runsInTerminal = runsInTerminal
    }
}

public enum CanvasCommentDelivery {
    public enum Decision: Sendable, Equatable {
        case send(String)
        case drop
        case waitForDocument
    }

    public static func wait(
        of comment: CanvasComment, in place: CanvasCommentPlace = CanvasCommentPlace(), behind pending: [Delivery], chat: CanvasCommentChat?
    ) -> CanvasCommentWait? {
        guard comment.state == .queued else { return nil }
        if CanvasCommentOrigin.cameWithFile(comment, addedThisRun: place.addedThisRun) { return .cameWithFile }
        if place.archiving { return .archiving }
        if place.documentHeld { return .documentHeld }
        guard let delivery = comment.deliveryID else { return .noChat }
        guard let chat else { return nil }
        if chat.runsInTerminal { return .terminalChat }
        if chat.rewindInterrupted { return .rewindInterrupted }
        if chat.stoppedByHand { return .stoppedByHand }
        if chat.heldAfterRewind, !Delivery.messages(in: pending).isEmpty { return .messageHeldAfterRewind }
        if chat.draftBeingEdited { return .draftBeingEdited }
        if chat.hold != .none { return .held(chat.hold) }
        if chat.savingTurn { return .savingTurn }
        guard Delivery.messages(in: pending).isEmpty else { return .messageAhead }
        return pending.first?.id == delivery || pending.first == nil ? .nextInLine : .commentAhead
    }

    public static func mayStart(under hold: DeliveryHold, draftBeingEdited: Bool = false) -> Bool {
        hold == .none && !draftBeingEdited
    }

    public static func awaitingChatAgain(_ id: CanvasCommentID, in document: CanvasDocument) -> CanvasDocument {
        var changed = document
        for index in changed.comments.indices
        where changed.comments[index].id == id && changed.comments[index].state != .working
            && CanvasCommentFlow.owesAnAnswer(changed.comments[index].state) {
            changed.comments[index].deliveryID = nil
            changed.comments[index].state = .queued
        }
        return changed
    }

    public static func rowBelongs(_ row: Delivery, to comment: CanvasComment, path: String) -> Bool {
        row.isCanvasComment && row.canvasDocumentPath == path && CanvasCommentFlow.quotes(comment, inMessage: row.body)
    }

    public static func rowIsLive(_ row: Delivery?, target: Session?) -> Bool {
        guard let row, row.state != .accepted, let target else { return false }
        return target.archivedAt == nil
    }

    public static func couldNotQueue(_ id: CanvasCommentID, in document: CanvasDocument) -> CanvasDocument {
        var changed = document
        for index in changed.comments.indices
        where changed.comments[index].id == id && CanvasCommentFlow.owesAnAnswer(changed.comments[index].state) {
            changed.comments[index].state = .unanswered
        }
        return changed
    }

    public static func delivery(
        for comment: CanvasComment, path: String, in document: CanvasDocument, to session: SessionID,
        addedThisRun: inout CanvasCommentsAddedThisRun, now: Date
    ) -> Delivery? {
        guard CanvasCommentFlow.owesAnAnswer(comment.state),
              !CanvasCommentOrigin.cameWithFile(comment, addedThisRun: addedThisRun) else { return nil }
        let goesLast = addedThisRun.goesLast(comment)
        addedThisRun.consume(comment.id)
        let delivery = Delivery(
            targetSessionID: session,
            kind: .canvasComment,
            body: CanvasCommentFlow.message(for: comment, path: path, in: document),
            createdAt: goesLast ? now : comment.createdAt,
            canvasDocumentPath: path
        )
        addedThisRun.noteSent(delivery.id)
        return delivery
    }

    public static func documentPath(of delivery: Delivery, worktree: String) -> String? {
        guard let path = delivery.canvasDocumentPath,
              case .file(let absolute, _) = CanvasFile.contained(path: path, worktree: worktree),
              CanvasDocumentFile.isDocument(path: absolute) else { return nil }
        return absolute
    }

    public static func decide(
        _ delivery: Delivery, in document: CanvasDocumentDecoding?, documentHeld: Bool = false
    ) -> Decision {
        guard delivery.state == .pending, let path = delivery.canvasDocumentPath,
              case .document(let held) = document else { return .drop }
        let claimants = held.comments.filter { $0.deliveryID == delivery.id }
        guard claimants.count == 1, let comment = claimants.first, CanvasCommentFlow.owesAnAnswer(comment.state),
              CanvasCommentFlow.quotes(comment, inMessage: delivery.body) else { return .drop }
        if documentHeld { return .waitForDocument }
        return .send(CanvasCommentFlow.message(for: comment, path: path, in: held))
    }

    public static func assigned(
        _ id: CanvasCommentID, to delivery: DeliveryID, in document: CanvasDocument
    ) -> CanvasDocument {
        var changed = document
        for index in changed.comments.indices
        where changed.comments[index].id == id && CanvasCommentFlow.owesAnAnswer(changed.comments[index].state) {
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

    public static func awaitingChat(in document: CanvasDocument, addedThisRun: CanvasCommentsAddedThisRun) -> [CanvasComment] {
        document.comments.filter { comment in
            comment.state == .queued && comment.deliveryID == nil
                && !CanvasCommentOrigin.cameWithFile(comment, addedThisRun: addedThisRun)
        }
    }

    public static func deliveriesToCheck(in document: CanvasDocument, excluding beingSent: Set<DeliveryID>) -> Set<DeliveryID> {
        Set(document.comments.filter { $0.state == .queued }.compactMap(\.deliveryID)).subtracting(beingSent)
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
