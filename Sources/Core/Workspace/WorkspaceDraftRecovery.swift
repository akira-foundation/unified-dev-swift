import Foundation

public enum WorkspaceDraftRecovery {
    public enum Fate: Sendable, Equatable {
        case keep
        case finished
        case handOver(SessionID)
    }

    public struct Outcome: Sendable, Equatable {
        public var kept: [WorkspaceDraft] = []
        public var finished: [WorkspaceDraft] = []
        public var handedOver: [WorkspaceDraft] = []
    }

    public static func fate(
        of draft: WorkspaceDraft, workspaceExists: Bool, promptArrived: Bool, firstSession: SessionID?
    ) -> Fate {
        guard draft.creatingAs != nil, workspaceExists else { return .keep }
        guard !promptArrived, draft.hasContent else { return .finished }
        return firstSession.map(Fate.handOver) ?? .keep
    }

    public static func settle(in store: Store) async throws -> Outcome {
        var outcome = Outcome()
        for draft in try await store.workspaceDrafts() {
            switch try await fate(of: draft, in: store) {
            case .keep:
                if draft.creatingAs != nil {
                    try await store.update(workspaceDraftFor: draft.repoID) { $0.creatingAs = nil }
                }
                var kept = draft
                kept.creatingAs = nil
                outcome.kept.append(kept)
            case .finished:
                try await store.deleteWorkspaceDraft(repoID: draft.repoID)
                outcome.finished.append(draft)
            case .handOver(let sessionID):
                let waiting = try await store.draft(sessionID: sessionID)
                try await store.saveDraft(
                    sessionID: sessionID, body: WorkspaceDraft.receiving(draft.prompt, into: waiting)
                )
                try await store.deleteWorkspaceDraft(repoID: draft.repoID)
                outcome.handedOver.append(draft)
            }
        }
        return outcome
    }

    private static func fate(of draft: WorkspaceDraft, in store: Store) async throws -> Fate {
        guard let id = draft.creatingAs, try await store.workspace(id: id) != nil else {
            return fate(of: draft, workspaceExists: false, promptArrived: false, firstSession: nil)
        }
        let sessions = try await store.sessions(workspaceID: id)
        var promptArrived = false
        for session in sessions where !promptArrived {
            let queued = try await store.pendingDeliveries(sessionID: session.id)
            let spoken = try await store.messages(sessionID: session.id, limit: 1)
            promptArrived = !queued.isEmpty || !spoken.isEmpty
        }
        return fate(
            of: draft, workspaceExists: true, promptArrived: promptArrived, firstSession: sessions.first?.id
        )
    }
}
