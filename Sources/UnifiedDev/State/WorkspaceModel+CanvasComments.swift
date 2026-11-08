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

    func canvasCommentBegan(_ delivery: Delivery, sessionID: SessionID) {
        canvasCommentTurns.began(delivery.id, in: sessionID)
    }

    func canvasTurnStopped(sessionID: SessionID) {
        guard let turn = canvasCommentTurns.stop(in: sessionID) else { return }
        end(turn)
    }

    func canvasCommentNotSent(_ delivery: Delivery, sessionID: SessionID, stillQueued: Bool) {
        canvasCommentTurns.end(delivery.id, in: sessionID)
        canvasDocument(of: delivery)?.canvasCommentNotSent(deliveryID: delivery.id, stillQueued: stillQueued)
    }

    func settleCanvasComments(in canvas: CanvasDocumentModel) async {
        guard let store, case .document(let held) = canvas.document else { return }
        let checked = CanvasCommentDelivery.deliveriesToCheck(in: held, excluding: canvasCommentsBeingSent)
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
        canvas.commentRowsBelonging = await canvasCommentRowsBelonging(to: canvas, in: store)
        await sendCanvasCommentsAwaitingChat(in: canvas)
    }

    private func canvasCommentRowsBelonging(to canvas: CanvasDocumentModel, in store: Store) async -> Set<DeliveryID> {
        guard case .document(let held) = canvas.document else { return [] }
        var proven: Set<DeliveryID> = []
        for comment in CanvasCommentOrigin.awaitingProof(in: held) {
            guard let id = comment.deliveryID, let row = try? await store.delivery(id: id),
                  CanvasCommentDelivery.rowBelongs(row, to: comment, path: canvas.path) else { continue }
            proven.insert(id)
        }
        return proven
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
                  for: comment, path: canvas.path, in: held, to: session.id,
                  addedThisRun: &canvas.commentsAddedThisRun, now: Date()
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
            cancel: { [weak self, weak canvas] delivery, comment, wakesTheRest in
                guard let self, let canvas else { return .failed("The workspace has closed.") }
                return await self.cancelCanvasComment(delivery, of: comment, in: canvas, wakesTheRest: wakesTheRest)
            },
            released: { [weak self] delivery in self?.canvasCommentsBeingSent.remove(delivery) },
            say: { [weak self] sentence in self?.noteCanvasComment(sentence) },
            wait: { [weak self, weak canvas] comment in
                guard let self, let canvas else { return nil }
                return self.canvasCommentWait(of: comment, in: canvas)
            }
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

    private func canvasCommentWait(of comment: CanvasComment, in canvas: CanvasDocumentModel) -> CanvasCommentWait? {
        let transcript = comment.deliveryID.flatMap { canvasCommentTargets[$0] }.flatMap(existingTranscript(for:))
        return CanvasCommentDelivery.wait(
            of: comment, in: canvasCommentPlace(of: canvas), behind: transcript?.pendingDeliveries ?? [], chat: transcript?.canvasCommentChat
        )
    }

    private func routeCanvasComment(_ id: CanvasCommentID, in canvas: CanvasDocumentModel) async -> CanvasCommentSending {
        await sendCanvasComment(id, in: canvas, besideChat: chatBesideCanvas, shownBy: canvasShownBy[canvas.path])
    }

    private func sendCanvasCommentsAwaitingChat(in canvas: CanvasDocumentModel) async {
        while let next = canvas.commentsAwaitingChat.first {
            guard await routeCanvasComment(next.id, in: canvas) == .queued else { return }
        }
    }

    private func cancelCanvasComment(
        _ delivery: DeliveryID, of comment: CanvasComment, in canvas: CanvasDocumentModel, wakesTheRest: Bool
    ) async -> CanvasCommentCancelAnswer {
        canvasCommentsBeingSent.insert(delivery)
        let answer = await cancelledRow(delivery, of: comment, in: canvas)
        guard let transcript = canvasCommentTargets[delivery].flatMap(existingTranscript(for:)) else { return answer }
        await transcript.refreshQueue()
        if wakesTheRest { await transcript.drainIfOnlyCanvasCommentsWait() }
        return answer
    }

    private func cancelledRow(
        _ delivery: DeliveryID, of comment: CanvasComment, in canvas: CanvasDocumentModel
    ) async -> CanvasCommentCancelAnswer {
        guard let store else { return .failed("The database is not open.") }
        do {
            guard let row = try await store.delivery(id: delivery),
                  CanvasCommentDelivery.rowBelongs(row, to: comment, path: canvas.path) else { return .removed }
            if try await store.cancelDelivery(id: delivery) { return .removed }
            return .afterRefusal(row: try await store.delivery(id: delivery))
        } catch {
            return .failed(error.readableMessage)
        }
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
