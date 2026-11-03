import Foundation
import Core

extension WorkspaceModel {
    func canvasCommentDispatch(of delivery: Delivery) -> CanvasCommentDelivery.Decision {
        guard let canvas = canvasDocument(of: delivery) else { return .drop }
        return canvas.canvasCommentDispatch(of: delivery)
    }

    func canvasCommentStarted(_ delivery: Delivery, sessionID: SessionID) {
        guard let canvas = canvasDocument(of: delivery) else { return }
        let turn = CanvasCommentTurn(deliveryID: delivery.id, path: canvas.path)
        if let displaced = canvasCommentTurns.start(turn, in: sessionID) { end(displaced) }
        canvas.canvasCommentStarted(deliveryID: delivery.id)
    }

    @discardableResult
    func canvasTurnEnded(sessionID: SessionID) -> Bool {
        guard let turn = canvasCommentTurns.end(in: sessionID) else { return false }
        end(turn)
        return true
    }

    func canvasCommentNotSent(_ delivery: Delivery, sessionID: SessionID, stillQueued: Bool) {
        canvasCommentTurns.end(delivery.id, in: sessionID)
        canvasDocument(of: delivery)?.canvasCommentNotSent(deliveryID: delivery.id, stillQueued: stillQueued)
    }

    func settleCanvasComments(in canvas: CanvasDocumentModel) async {
        guard let store, case .document(let held) = canvas.document else { return }
        let checked = CanvasCommentDelivery.deliveriesToCheck(in: held)
        var live: Set<DeliveryID> = []
        for id in checked where await canvasCommentRowIsLive(id, in: store) {
            live.insert(id)
        }
        let inFlight = canvasCommentTurns.deliveries(inDocument: canvas.path)
        canvas.changeComments {
            CanvasCommentDelivery.settled($0, inFlight: inFlight, checked: checked, live: live)
        }
    }

    @discardableResult
    func sendCanvasComment(
        _ id: CanvasCommentID, in canvas: CanvasDocumentModel, besideChat: SessionID?, shownBy: SessionID?
    ) async -> Bool {
        let target = CanvasCommentRouting.target(besideChat: besideChat, shownBy: shownBy, active: activeSession?.id)
        guard let session = sessions.first(where: { $0.id == target }),
              case .document(let held) = canvas.document,
              let comment = held.comments.first(where: { $0.id == id }) else { return false }
        let transcript = transcript(for: session)
        guard transcript.acceptsMessages else { return false }
        let delivery = CanvasCommentDelivery.delivery(
            for: comment, path: canvas.path, in: held, to: session.id, createdAt: Date()
        )
        return await transcript.queueCanvasComment(delivery) {
            canvas.changeComments { CanvasCommentDelivery.assigned(id, to: delivery.id, in: $0) }
        }
    }

    private func end(_ turn: CanvasCommentTurn) {
        existingCanvasDocument(path: turn.path)?.canvasCommentTurnEnded(deliveryID: turn.deliveryID)
    }

    private func canvasDocument(of delivery: Delivery) -> CanvasDocumentModel? {
        guard let path = CanvasCommentDelivery.documentPath(of: delivery, worktree: workspace.path) else { return nil }
        if let open = existingCanvasDocument(path: path) { return open }
        guard FileManager.default.fileExists(atPath: path) else { return nil }
        return canvasDocument(path: path)
    }

    private func canvasCommentRowIsLive(_ id: DeliveryID, in store: Store) async -> Bool {
        do {
            guard let row = try await store.delivery(id: id), row.state != .accepted else { return false }
            let target = try await store.session(id: row.targetSessionID)
            guard let target else { return false }
            return target.archivedAt == nil
        } catch {
            return true
        }
    }
}
