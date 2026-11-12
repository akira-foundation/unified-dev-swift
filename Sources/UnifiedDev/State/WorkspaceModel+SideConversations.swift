import Core
import Foundation

extension WorkspaceModel {
    @discardableResult
    func openSideConversation(
        from parent: TranscriptModel, question: String = "", fresh: Bool = false, quoting: String = ""
    ) -> Bool {
        guard parent.session.sideConversationParentID == nil, store != nil else { return false }
        let parentID = parent.session.id
        let state = sideConversations[parentID] ?? SideConversationState()
        sideConversations[parentID] = state
        guard !state.isKeeping else { return false }
        switch state.lifecycle.start(question: question, quoting: quoting, fresh: fresh) {
        case .wait:
            return true
        case .resume(let id, let arrival):
            guard let child = state.transcript, child.session.id == id else { return false }
            deliver(arrival, to: child)
            return true
        case .open(let opening):
            begin(opening, from: parent, state: state)
            return true
        }
    }

    private func begin(
        _ opening: SideConversationLifecycle.Opening, from parent: TranscriptModel, state: SideConversationState
    ) {
        let parentID = parent.session.id
        state.error = nil
        state.task?.cancel()
        state.task = Task { [weak self] in
            guard let self, let store else { return }
            do {
                if let previous = opening.keeping {
                    _ = try await store.keepSideConversation(sessionID: previous)
                    state.transcript = nil
                    state.snapshot = nil
                }
                try Task.checkCancellation()
                let session = try await store.openSideConversation(
                    parentID: parentID, streamingText: parent.streamingText
                )
                let snapshot = try await store.sideConversationSnapshot(sessionID: session.id)
                guard let arrival = state.lifecycle.opened(session.id, generation: opening.generation) else {
                    try await store.closeSideConversation(sessionID: session.id)
                    return
                }
                await reloadSessions()
                guard state.lifecycle.sessionID == session.id else { return }
                let child = transcript(for: session)
                state.transcript = child
                state.snapshot = snapshot
                await child.load()
                guard state.lifecycle.sessionID == session.id else { return }
                deliver(arrival, to: child)
                if state.isVisible { child.focusComposer() }
            } catch is CancellationError {
                state.lifecycle.failed(generation: opening.generation)
            } catch {
                state.lifecycle.failed(generation: opening.generation)
                state.error = error.readableMessage
            }
        }
    }

    private func deliver(_ arrival: SideConversationLifecycle.Arrival, to child: TranscriptModel) {
        arrival.quotes.forEach { child.reply(with: $0) }
        guard !arrival.question.isEmpty else { return }
        Task { await child.submit(arrival.question) }
    }

    func dismissSideConversation(from parent: TranscriptModel) {
        sideConversations[parent.session.id]?.lifecycle.hide()
        parent.focusComposer()
    }

    func closeSideConversation(from parent: TranscriptModel) {
        guard let state = sideConversations[parent.session.id], !state.isKeeping else { return }
        state.task?.cancel()
        state.task = nil
        let ending = state.lifecycle.close()
        let child = state.transcript
        state.transcript = nil
        state.snapshot = nil
        state.error = nil
        parent.focusComposer()
        guard let id = ending ?? child?.session.id else { return }
        endSideConversation(id)
    }

    func keepSideConversation(from parent: TranscriptModel) {
        guard let state = sideConversations[parent.session.id], let child = state.transcript,
              !state.isKeeping, state.lifecycle.sessionID == child.session.id, let store else { return }
        state.isKeeping = true
        state.task = Task { [weak self] in
            defer { state.isKeeping = false; state.task = nil }
            guard let self else { return }
            do {
                guard let kept = try await store.keepSideConversation(sessionID: child.session.id) else { return }
                try Task.checkCancellation()
                child.session = kept
                _ = state.lifecycle.keep()
                state.transcript = nil
                state.snapshot = nil
                await reloadSessions()
                WorkspaceTabsStore.shared.reveal(.chat(kept.id), in: self)
            } catch is CancellationError {
            } catch {
                state.error = error.readableMessage
            }
        }
    }
}
