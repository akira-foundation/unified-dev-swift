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
        case .resume(_, let arrival):
            guard let child = state.transcript else { return false }
            state.task = Task { await deliver(arrival, to: child, state: state) }
            return true
        case .open(let opening):
            begin(opening, from: parent, state: state)
            return true
        }
    }

    private func begin(
        _ opening: SideConversationLifecycle.Opening, from parent: TranscriptModel, state: SideConversationState
    ) {
        guard let store else { return }
        let parentID = parent.session.id
        let previous = state.transcript
        state.transcript = nil
        state.snapshot = nil
        state.error = nil
        state.task?.cancel()
        state.task = Task { [weak self] in
            guard let self else { return }
            if let kept = opening.keeping {
                do {
                    _ = try await store.keepSideConversation(sessionID: kept)
                    await reloadSessions()
                } catch {
                    guard state.lifecycle.keepFailed(generation: opening.generation, restoring: kept) else { return }
                    state.transcript = previous
                    state.error = error.readableMessage
                    return
                }
            }
            do {
                try Task.checkCancellation()
                let session = try await store.openSideConversation(
                    parentID: parentID, streamingText: parent.streamingText
                )
                guard state.lifecycle.opened(session.id, generation: opening.generation) else {
                    try await store.closeSideConversation(sessionID: session.id)
                    return
                }
                let snapshot = try await store.sideConversationSnapshot(sessionID: session.id)
                await reloadSessions()
                guard state.lifecycle.isOpening(session.id, generation: opening.generation) else { return }
                let child = transcript(for: session)
                state.transcript = child
                state.snapshot = snapshot
                await child.load()
                guard let arrival = state.lifecycle.ready(generation: opening.generation) else { return }
                if state.isVisible { child.focusComposer() }
                await deliver(arrival, to: child, state: state)
            } catch is CancellationError {
                state.lifecycle.failed(generation: opening.generation)
            } catch {
                state.lifecycle.failed(generation: opening.generation)
                state.error = error.readableMessage
            }
        }
    }

    private func deliver(
        _ arrival: SideConversationLifecycle.Arrival, to child: TranscriptModel, state: SideConversationState
    ) async {
        arrival.quotes.forEach { child.reply(with: $0) }
        for question in arrival.questions {
            guard state.lifecycle.sessionID == child.session.id else { return }
            await child.submit(question)
        }
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
        state.transcript = nil
        state.snapshot = nil
        state.error = nil
        parent.focusComposer()
        guard let ending else { return }
        endSideConversation(ending)
    }

    func keepSideConversation(from parent: TranscriptModel) {
        guard let state = sideConversations[parent.session.id], let child = state.transcript,
              !state.isKeeping, state.lifecycle.sessionID == child.session.id, let store else { return }
        state.isKeeping = true
        state.task?.cancel()
        state.task = Task { [weak self] in
            defer { state.isKeeping = false; state.task = nil }
            guard let self else { return }
            do {
                guard let kept = try await store.keepSideConversation(sessionID: child.session.id) else { return }
                child.session = kept
                _ = state.lifecycle.keep()
                state.transcript = nil
                state.snapshot = nil
                await reloadSessions()
                WorkspaceTabsStore.shared.reveal(.chat(kept.id), in: self)
            } catch {
                state.error = error.readableMessage
            }
        }
    }
}
