import Foundation

public struct CanvasCommentResolveOrder: Sendable, Equatable {
    public var path: String
    public var commentID: CanvasCommentID
    public var state: CanvasComment.State
    public var response: String
    public var caller: SessionID?

    public init(path: String, commentID: CanvasCommentID, state: CanvasComment.State, response: String, caller: SessionID?) {
        self.path = path
        self.commentID = commentID
        self.state = state
        self.response = response
        self.caller = caller
    }
}

public struct CanvasCommentHandover: Sendable, Equatable {
    public var delivery: DeliveryID
    public var target: SessionID?

    public init(delivery: DeliveryID, target: SessionID?) {
        self.delivery = delivery
        self.target = target
    }
}

public struct CanvasCommentResolveResult: Sendable, Equatable {
    public var state: CanvasComment.State
    public var disk: CanvasDiskOutcome

    public init(state: CanvasComment.State, disk: CanvasDiskOutcome) {
        self.state = state
        self.disk = disk
    }
}

public enum CanvasCommentResolveOutcome: Sendable, Equatable {
    case resolved(CanvasCommentResolveResult)
    case refused(String)
}

public struct CanvasPendingCommentResolve: Sendable, Equatable {
    public let state: CanvasComment.State
    let reloadsBefore: Int
}

public enum CanvasCommentResolveStart: Sendable, Equatable {
    case refused(String)
    case pending(CanvasPendingCommentResolve)
}

public enum CanvasCommentResolve {
    public static func begin(
        _ order: CanvasCommentResolveOrder, handover: CanvasCommentHandover?, on keeper: inout CanvasDocumentKeeper
    ) -> CanvasCommentResolveStart {
        if let refusal = CanvasAgentEdit.refusal(for: keeper) { return .refused(refusal) }
        guard case .document(let held) = keeper.document else { return .refused("This canvas has not been read.") }
        if let comment = held.comments.first(where: { $0.id == order.commentID }), CanvasCommentFlow.owesAnAnswer(comment.state),
           let refusal = refusal(of: order.caller, answering: comment, handover: handover) {
            return .refused(refusal)
        }
        let reloadsBefore = keeper.reloads
        switch CanvasCommentFlow.resolve(order.commentID, as: order.state, saying: order.response, in: held) {
        case .refused(let sentence):
            return .refused(sentence)
        case .resolved(let changed):
            keeper.changeComments { _ in changed }
            return .pending(CanvasPendingCommentResolve(state: order.state, reloadsBefore: reloadsBefore))
        }
    }

    public static func conclude(_ pending: CanvasPendingCommentResolve, on keeper: CanvasDocumentKeeper) -> CanvasCommentResolveResult {
        CanvasCommentResolveResult(
            state: pending.state, disk: CanvasAgentEdit.disk(reloadsBefore: pending.reloadsBefore, on: keeper)
        )
    }

    private static func refusal(
        of caller: SessionID?, answering comment: CanvasComment, handover: CanvasCommentHandover?
    ) -> String? {
        let name = comment.id.rawValue
        guard let delivery = comment.deliveryID else {
            return "Comment '\(name)' has not been sent to any chat yet, so nothing was changed. It is sent when the person has a chat for it."
        }
        guard let handover, handover.delivery == delivery else {
            return "Comment '\(name)' was sent again while this was being checked, so nothing was changed. Read the canvas again."
        }
        guard let target = handover.target else {
            return "Comment '\(name)' is no longer with any chat, so nothing was changed. The person can send it again."
        }
        guard target == caller else {
            return "Comment '\(name)' was sent to another chat in this workspace, and only that chat can answer it. Nothing was changed."
        }
        return nil
    }
}
