import Foundation
import Observation
import Core

@MainActor
@Observable
final class WorkspaceDrafts {
    private(set) var byRepo: [RepoID: WorkspaceDraft] = [:]
    private(set) var creating: [RepoID: WorkspaceID] = [:]
    private(set) var failures: [RepoID: String] = [:]
    private(set) var originAsks: Set<RepoID> = []

    @ObservationIgnored private var stored: Set<RepoID> = []
    @ObservationIgnored private var cameFrom: [RepoID: SidebarSelection] = [:]
    @ObservationIgnored private var writes: [RepoID: Task<Void, Never>] = [:]

    private static let writeDelay: Duration = .milliseconds(500)

    var creatingWorkspaceIDs: Set<WorkspaceID> { Set(creating.values) }

    func draft(for repoID: RepoID) -> WorkspaceDraft? { byRepo[repoID] }

    func isCreating(_ repoID: RepoID) -> Bool { creating[repoID] != nil }

    func failure(for repoID: RepoID) -> String? { failures[repoID] }

    func returnTarget(for repoID: RepoID) -> SidebarSelection? { cameFrom[repoID] }

    func adopt(_ loaded: [WorkspaceDraft]) {
        for draft in loaded where byRepo[draft.repoID] == nil {
            byRepo[draft.repoID] = draft
        }
        stored.formUnion(loaded.map(\.repoID))
    }

    func open(_ fresh: WorkspaceDraft, from selection: SidebarSelection) {
        if byRepo[fresh.repoID] == nil { byRepo[fresh.repoID] = fresh }
        guard selection.draftRepoID == nil else { return }
        cameFrom[fresh.repoID] = selection
    }

    func edit(_ repoID: RepoID, store: Store?, _ change: (inout WorkspaceDraft) -> Void) {
        guard let current = byRepo[repoID] else { return }
        var draft = current
        change(&draft)
        guard draft != current else { return }
        draft.updatedAt = Date()
        byRepo[repoID] = draft
        failures[repoID] = nil
        writes[repoID]?.cancel()
        writes[repoID] = Task { [weak self] in
            try? await Task.sleep(for: Self.writeDelay)
            guard !Task.isCancelled else { return }
            await self?.flush(repoID, store: store)
        }
    }

    func flush(_ repoID: RepoID, store: Store?) async {
        writes[repoID]?.cancel()
        writes[repoID] = nil
        guard let store else { return }
        let draft = byRepo[repoID]
        switch WorkspaceDraftWrite.decide(hasContent: draft?.hasContent ?? false, isStored: stored.contains(repoID)) {
        case .insert, .update:
            guard let draft else { return }
            stored.insert(repoID)
            await Self.write(draft, to: store)
        case .delete:
            stored.remove(repoID)
            try? await store.deleteWorkspaceDraft(repoID: repoID)
        case .nothing:
            break
        }
    }

    func flushAll(store: Store?) async {
        for repoID in Array(writes.keys) { await flush(repoID, store: store) }
    }

    func remove(_ repoID: RepoID, store: Store?) {
        writes[repoID]?.cancel()
        writes[repoID] = nil
        byRepo[repoID] = nil
        creating[repoID] = nil
        failures[repoID] = nil
        originAsks.remove(repoID)
        cameFrom[repoID] = nil
        guard stored.remove(repoID) != nil, let store else { return }
        Task { try? await store.deleteWorkspaceDraft(repoID: repoID) }
    }

    func move(_ repoID: RepoID, to moved: WorkspaceDraft, store: Store?) {
        writes[repoID]?.cancel()
        writes[repoID] = nil
        byRepo[repoID] = nil
        byRepo[moved.repoID] = moved
        failures[repoID] = nil
        cameFrom[moved.repoID] = cameFrom.removeValue(forKey: repoID)
        guard stored.remove(repoID) != nil, let store else { return }
        stored.insert(moved.repoID)
        Task {
            _ = try? await store.moveWorkspaceDraft(from: repoID, to: moved.repoID)
            await Self.write(moved, to: store)
        }
    }

    func beginCreating(_ repoID: RepoID, as id: WorkspaceID) {
        creating[repoID] = id
        failures[repoID] = nil
    }

    func fail(_ repoID: RepoID, sentence: String) {
        creating[repoID] = nil
        failures[repoID] = sentence
    }

    func askForOrigin(_ repoID: RepoID) {
        originAsks.insert(repoID)
    }

    func consumeOriginAsk(_ repoID: RepoID) -> Bool {
        originAsks.remove(repoID) != nil
    }

    private static func write(_ draft: WorkspaceDraft, to store: Store) async {
        let updated = try? await store.update(workspaceDraftFor: draft.repoID) { $0 = draft }
        guard updated == nil else { return }
        _ = try? await store.insert(draft)
    }
}
