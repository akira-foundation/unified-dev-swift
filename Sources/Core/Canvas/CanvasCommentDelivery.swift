import Foundation

public enum CanvasCommentWait: Sendable, Equatable {
    case noChat
    case archiving
    case terminalChat
    case rewindInterrupted
    case stoppedByHand
    case draftBeingEdited
    case held(DeliveryHold)
    case savingTurn
    case messageAhead
    case commentAhead
    case nextInLine
}

public struct CanvasCommentChat: Sendable, Equatable {
    public var stoppedByHand: Bool
    public var draftBeingEdited: Bool
    public var hold: DeliveryHold
    public var archiving: Bool
    public var savingTurn: Bool
    public var rewindInterrupted: Bool
    public var runsInTerminal: Bool

    public init(
        stoppedByHand: Bool = false,
        draftBeingEdited: Bool = false,
        hold: DeliveryHold = .none,
        archiving: Bool = false,
        savingTurn: Bool = false,
        rewindInterrupted: Bool = false,
        runsInTerminal: Bool = false
    ) {
        self.stoppedByHand = stoppedByHand
        self.draftBeingEdited = draftBeingEdited
        self.hold = hold
        self.archiving = archiving
        self.savingTurn = savingTurn
        self.rewindInterrupted = rewindInterrupted
        self.runsInTerminal = runsInTerminal
    }
}

public enum CanvasCommentDelivery {
    public enum Decision: Sendable, Equatable {
        case send(String)
        case drop
    }

    public static func wait(
        of comment: CanvasComment, behind pending: [Delivery], chat: CanvasCommentChat
    ) -> CanvasCommentWait? {
        guard comment.state == .queued else { return nil }
        guard let delivery = comment.deliveryID else { return .noChat }
        if chat.archiving { return .archiving }
        if chat.runsInTerminal { return .terminalChat }
        if chat.rewindInterrupted { return .rewindInterrupted }
        if chat.stoppedByHand { return .stoppedByHand }
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
        for comment: CanvasComment, path: String, in document: CanvasDocument, to session: SessionID, createdAt: Date
    ) -> Delivery? {
        guard CanvasCommentFlow.owesAnAnswer(comment.state) else { return nil }
        return Delivery(
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
