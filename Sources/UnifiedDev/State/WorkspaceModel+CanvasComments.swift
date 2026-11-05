import Foundation
import Core

enum CanvasCommentSending {
    case queued
    case awaitingChat
    case notQueued
}

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
        let checked = CanvasCommentDelivery.deliveriesToCheck(in: held).subtracting(canvasCommentsBeingSent)
        var live: Set<DeliveryID> = []
        for id in checked {
            let row = await canvasCommentRow(id, in: store)
            guard row.isLive else { continue }
            live.insert(id)
            if let target = row.target { noteCanvasCommentTarget(target, of: id) }
        }
        let inFlight = canvasCommentTurns.deliveries(inDocument: canvas.path)
        canvas.changeComments {
            CanvasCommentDelivery.settled($0, inFlight: inFlight, checked: checked, live: live)
        }
        canvas.confirmCommentDeliveries(CanvasCommentBoard.confirmed(
            previously: canvas.confirmedCommentDeliveries, checked: checked, live: live
        ))
        await sendCanvasCommentsAwaitingChat(in: canvas)
    }

    @discardableResult
    func sendCanvasComment(
        _ id: CanvasCommentID, in canvas: CanvasDocumentModel, besideChat: SessionID?, shownBy: SessionID?
    ) async -> CanvasCommentSending {
        let target = CanvasCommentRouting.target(besideChat: besideChat, shownBy: shownBy, active: activeSession?.id) { chat in
            sessions.first { $0.id == chat }.map { transcript(for: $0).acceptsMessages } ?? false
        }
        guard let session = sessions.first(where: { $0.id == target }) else { return .awaitingChat }
        guard case .document(let held) = canvas.document,
              let comment = held.comments.first(where: { $0.id == id }),
              let delivery = CanvasCommentDelivery.delivery(
                  for: comment, path: canvas.path, in: held, to: session.id, createdAt: comment.createdAt
              ) else { return .notQueued }
        canvasCommentsBeingSent.insert(delivery.id)
        defer { canvasCommentsBeingSent.remove(delivery.id) }
        canvasCommentTargets[delivery.id] = session.id
        canvas.confirmCommentDelivery(delivery.id)
        canvas.changeComments { CanvasCommentDelivery.assigned(id, to: delivery.id, in: $0) }
        guard await transcript(for: session).queueCanvasComment(delivery) else {
            canvas.changeComments { CanvasCommentDelivery.couldNotQueue(id, in: $0) }
            return .notQueued
        }
        return .queued
    }

    func sendOpenCanvasCommentsAwaitingChat() async {
        for canvas in openCanvasDocuments {
            await sendCanvasCommentsAwaitingChat(in: canvas)
        }
    }

    func canvasCommentCourier(for canvas: CanvasDocumentModel) -> CanvasCommentCourier {
        CanvasCommentCourier(
            send: { [weak self, weak canvas] id in
                guard let self, let canvas else { return .notQueued }
                return await self.routeCanvasComment(id, in: canvas)
            },
            cancel: { [weak self] delivery, wakesTheRest in
                await self?.cancelCanvasComment(delivery, wakesTheRest: wakesTheRest) ?? false
            },
            wait: { [weak self] comment in self?.canvasCommentWait(of: comment) }
        )
    }

    func canvasCommentHandover(of id: CanvasCommentID, in canvas: CanvasDocumentModel) async -> CanvasCommentHandover? {
        guard let store, case .document(let held) = canvas.document,
              let delivery = held.comments.first(where: { $0.id == id })?.deliveryID else { return nil }
        let row = try? await store.delivery(id: delivery)
        return CanvasCommentHandover(delivery: delivery, target: row?.targetSessionID)
    }

    func noteCanvasShown(path: String, by caller: SessionID?) {
        guard let caller else { return }
        canvasShownBy[path] = caller
    }

    private func canvasCommentWait(of comment: CanvasComment) -> CanvasCommentWait? {
        guard comment.state == .queued else { return nil }
        guard let delivery = comment.deliveryID else { return .noChat }
        return canvasCommentTargets[delivery].flatMap(existingTranscript(for:))?.canvasCommentWait(for: comment)
    }

    private func routeCanvasComment(_ id: CanvasCommentID, in canvas: CanvasDocumentModel) async -> CanvasCommentSending {
        await sendCanvasComment(id, in: canvas, besideChat: chatBesideCanvas, shownBy: canvasShownBy[canvas.path])
    }

    private func sendCanvasCommentsAwaitingChat(in canvas: CanvasDocumentModel) async {
        for comment in canvas.commentsAwaitingChat {
            guard await routeCanvasComment(comment.id, in: canvas) == .queued else { return }
        }
    }

    private func cancelCanvasComment(_ delivery: DeliveryID, wakesTheRest: Bool) async -> Bool {
        let removed = (try? await store?.cancelDelivery(id: delivery)) ?? false
        if !removed { noteCanvasCommentAlreadySent() }
        guard let transcript = canvasCommentTargets[delivery].flatMap(existingTranscript(for:)) else { return removed }
        await transcript.refreshQueue()
        if wakesTheRest { await transcript.drainIfOnlyCanvasCommentsWait() }
        return removed
    }

    private func noteCanvasCommentTarget(_ target: SessionID, of delivery: DeliveryID) {
        canvasCommentTargets[delivery] = target
        if let session = sessions.first(where: { $0.id == target }) { _ = transcript(for: session) }
    }

    func wakeQueuedCanvasComments() async {
        guard let store, let holding = try? await store.sessionsHoldingCanvasComments(workspaceID: workspace.id) else { return }
        for id in holding {
            guard let session = sessions.first(where: { $0.id == id }),
                  CenterTabStore.shared.terminal(for: id, in: workspace.id) == nil else { continue }
            let transcript = transcript(for: session)
            guard transcript.acceptsMessages else { continue }
            await transcript.drainIfOnlyCanvasCommentsWait()
        }
    }

    func settleOpenCanvasComments() async {
        for canvas in openCanvasDocuments {
            await settleCanvasComments(in: canvas)
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

    private func canvasCommentRow(_ id: DeliveryID, in store: Store) async -> (isLive: Bool, target: SessionID?) {
        do {
            guard let row = try await store.delivery(id: id) else { return (false, nil) }
            let isLive = CanvasCommentDelivery.rowIsLive(row, target: try await store.session(id: row.targetSessionID))
            return (isLive, row.targetSessionID)
        } catch {
            return (true, nil)
        }
    }
}
