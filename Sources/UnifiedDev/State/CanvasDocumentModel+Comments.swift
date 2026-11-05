import Foundation
import Core

struct CanvasCommentCourier {
    let send: @MainActor (CanvasCommentID) async -> CanvasCommentSending
    let cancel: @MainActor (_ delivery: DeliveryID, _ comment: CanvasComment, _ wakesTheRest: Bool) async -> CanvasCommentCancelAnswer
    let released: @MainActor (DeliveryID) -> Void
    let say: @MainActor (String) -> Void
    let wait: @MainActor (CanvasComment) -> CanvasCommentWait?
}

extension CanvasDocumentModel {
    func canvasCommentDispatch(of delivery: Delivery) -> CanvasCommentDelivery.Decision {
        CanvasCommentDelivery.decide(delivery, in: keeper.document, documentHeld: keeper.holdsCanvasComments)
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
        return CanvasCommentDelivery.awaitingChat(in: held, addedThisRun: commentsAddedThisRun)
    }

    var commentMarks: [CanvasComment] {
        guard case .document(let held) = document else { return [] }
        return CanvasCommentBoard.marks(in: held, confirmed: confirmedCommentDeliveries)
    }

    var listedComments: [CanvasComment] {
        guard case .document(let held) = document else { return [] }
        return CanvasCommentBoard.listed(in: held)
    }

    func commentStatus(of comment: CanvasComment) -> CanvasCommentStatus {
        CanvasCommentBoard.status(of: comment, wait: commentCourier?.wait(comment))
    }

    @discardableResult
    func addComment(at point: CanvasPoint, text: String) async -> CanvasCommentID? {
        guard case .document(let held) = document,
              let comment = CanvasCommentFlow.placed(text: text, at: point, in: held, createdAt: Date()) else { return nil }
        commentsAddedThisRun.add(comment)
        changeComments { current in
            var changed = current
            changed.comments.append(comment)
            return changed
        }
        await send(comment.id)
        return comment.id
    }

    @discardableResult
    func editQueued(_ id: CanvasCommentID, text: String, applied: @MainActor () -> Void = {}) async -> Bool {
        guard case .document(let held) = keeper.document else { return report(.notEditable) }
        let outcome = await change(id, CanvasCommentEdit.beginEdit(id, text: text, in: held), wakesTheRest: false) { answer, current in
            CanvasCommentEdit.concludeEdit(id, text: text, answer: answer, in: current)
        }
        let spoke = report(outcome)
        if outcome == .unchanged { applied() }
        if case .changed(let changed) = outcome {
            if let edited = changed.comments.first(where: { $0.id == id }) { commentsAddedThisRun.addEdited(edited) }
            applied()
            await send(id)
        }
        return spoke
    }

    @discardableResult
    func deleteQueued(_ id: CanvasCommentID) async -> Bool {
        guard case .document(let held) = keeper.document else { return report(.notEditable) }
        let outcome = await change(id, CanvasCommentEdit.beginDelete(id, in: held), wakesTheRest: true) { answer, current in
            CanvasCommentEdit.concludeDelete(id, answer: answer, in: current)
        }
        commentsAddedThisRun.spend(after: outcome, deleting: id)
        return report(outcome)
    }

    @discardableResult
    func resend(_ shown: CanvasComment) async -> Bool {
        guard case .document(let held) = keeper.document else { return report(.notEditable) }
        let id = shown.id
        let start = CanvasCommentEdit.beginResend(id, showing: shown.text, in: held)
        let outcome = await change(id, start, wakesTheRest: false) { answer, current in
            CanvasCommentEdit.concludeResend(id, showing: shown.text, answer: answer, in: current)
        }
        if case .changed(let changed) = outcome {
            if let resent = changed.comments.first(where: { $0.id == id }) { commentsAddedThisRun.add(resent, goesLast: true) }
            await send(id)
        }
        return report(outcome)
    }

    func sendCommentFromFile(_ shown: CanvasComment) async {
        guard let current = comment(shown.id), current.text == shown.text,
              CanvasCommentBoard.canSend(current, addedThisRun: commentsAddedThisRun) else {
            _ = report(.notEditable)
            return
        }
        commentsAddedThisRun.add(current, goesLast: true)
        await send(current.id)
    }

    func canSendComment(_ comment: CanvasComment) -> Bool {
        CanvasCommentBoard.canSend(comment, addedThisRun: commentsAddedThisRun)
    }

    private func change(
        _ id: CanvasCommentID, _ start: CanvasCommentChangeStart, wakesTheRest: Bool,
        conclude: (CanvasCommentCancelAnswer, CanvasDocument) -> CanvasCommentChangeOutcome
    ) async -> CanvasCommentChangeOutcome {
        switch start {
        case .finished(let outcome):
            return outcome
        case .cancel(let delivery):
            var answer = CanvasCommentCancelAnswer.removed
            if let delivery, let courier = commentCourier, let comment = comment(id) {
                answer = await courier.cancel(delivery, comment, wakesTheRest)
            }
            defer { if let delivery { commentCourier?.released(delivery) } }
            guard case .document(let current) = keeper.document else { return .notEditable }
            let outcome = conclude(answer, current)
            if case .changed(let changed) = outcome { changeComments { _ in changed } }
            return outcome
        }
    }

    private func report(_ outcome: CanvasCommentChangeOutcome) -> Bool {
        guard let sentence = outcome.sentence else { return true }
        commentCourier?.say(sentence)
        return false
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
