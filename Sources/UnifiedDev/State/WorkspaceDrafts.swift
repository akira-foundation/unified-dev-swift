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
    private(set) var quietArrivals: Set<RepoID> = []

    @ObservationIgnored private var stored: Set<RepoID> = []
    @ObservationIgnored private var cameFrom: [RepoID: SidebarSelection] = [:]
    @ObservationIgnored private var writes: [RepoID: Task<Void, Never>] = [:]
    @ObservationIgnored private var queue: Task<Void, Never>?
    @ObservationIgnored private var heldArrivals: [RepoID: String] = [:]
    @ObservationIgnored private var staleWarnings: [RepoID: WorkspaceStartingPoint] = [:]

    private static let writeDelay: Duration = .milliseconds(500)

    var creatingWorkspaceIDs: Set<WorkspaceID> { Set(creating.values) }

    func draft(for repoID: RepoID) -> WorkspaceDraft? { byRepo[repoID] }

    func isCreating(_ repoID: RepoID) -> Bool { creating[repoID] != nil }

    func isCreating(_ repoID: RepoID, as id: WorkspaceID) -> Bool { creating[repoID] == id }

    func holdArrival(_ text: String, for repoID: RepoID) {
        heldArrivals[repoID] = WorkspaceDraft.receiving(text, into: heldArrivals[repoID] ?? "")
    }

    func takeArrival(for repoID: RepoID) -> String? {
        heldArrivals.removeValue(forKey: repoID)
    }

    func failure(for repoID: RepoID) -> String? { failures[repoID] }

    func staleWarning(for repoID: RepoID) -> WorkspaceStartingPoint? { staleWarnings[repoID] }

    func returnTarget(for repoID: RepoID) -> SidebarSelection? { cameFrom[repoID] }

    func holdsWork(_ repoID: RepoID) -> Bool {
        guard let draft = byRepo[repoID] else { return false }
        return draft.holdsWork(attachmentCount: PromptAttachmentStore.shared.attachments(for: draft.attachmentKey).count)
    }

    func arriveQuietly(_ repoID: RepoID) {
        quietArrivals.insert(repoID)
    }

    func consumeQuietArrival(_ repoID: RepoID) -> Bool {
        quietArrivals.remove(repoID) != nil
    }

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
        guard let current = byRepo[repoID], creating[repoID] == nil else { return }
        var draft = current
        change(&draft)
        guard draft != current else { return }
        draft.updatedAt = Date()
        byRepo[repoID] = draft
        failures[repoID] = nil
        staleWarnings[repoID] = nil
        scheduleWrite(repoID, store: store)
    }

    func flush(_ repoID: RepoID, store: Store?) async {
        writes[repoID]?.cancel()
        writes[repoID] = nil
        guard let store else { return }
        let draft = byRepo[repoID]
        switch WorkspaceDraftWrite.decide(hasContent: holdsWork(repoID), isStored: stored.contains(repoID)) {
        case .insert, .update:
            guard let draft else { return }
            stored.insert(repoID)
            await enqueue(store) { await Self.write(draft, to: $0) }.value
        case .delete:
            stored.remove(repoID)
            await enqueue(store) { try? await $0.deleteWorkspaceDraft(repoID: repoID) }.value
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
        staleWarnings[repoID] = nil
        originAsks.remove(repoID)
        cameFrom[repoID] = nil
        guard stored.remove(repoID) != nil, let store else { return }
        enqueue(store) { try? await $0.deleteWorkspaceDraft(repoID: repoID) }
    }

    func move(_ repoID: RepoID, to moved: WorkspaceDraft, store: Store?) {
        writes[repoID]?.cancel()
        writes[repoID] = nil
        byRepo[repoID] = nil
        byRepo[moved.repoID] = moved
        failures[repoID] = nil
        staleWarnings[repoID] = nil
        cameFrom[moved.repoID] = cameFrom.removeValue(forKey: repoID)
        guard stored.remove(repoID) != nil, let store else {
            scheduleWrite(moved.repoID, store: store)
            return
        }
        stored.insert(moved.repoID)
        enqueue(store) {
            _ = try? await $0.moveWorkspaceDraft(from: repoID, to: moved.repoID)
            await Self.write(moved, to: $0)
        }
    }

    func beginCreating(_ repoID: RepoID, as id: WorkspaceID) {
        creating[repoID] = id
        failures[repoID] = nil
        byRepo[repoID]?.creatingAs = id
    }

    func fail(_ repoID: RepoID, sentence: String, staleStart: WorkspaceStartingPoint?, store: Store?) {
        creating[repoID] = nil
        failures[repoID] = sentence
        staleWarnings[repoID] = staleStart
        byRepo[repoID]?.creatingAs = nil
        scheduleWrite(repoID, store: store)
    }

    func askForOrigin(_ repoID: RepoID) {
        originAsks.insert(repoID)
    }

    func consumeOriginAsk(_ repoID: RepoID) -> Bool {
        originAsks.remove(repoID) != nil
    }

    private func scheduleWrite(_ repoID: RepoID, store: Store?) {
        writes[repoID]?.cancel()
        writes[repoID] = Task { [weak self] in
            try? await Task.sleep(for: Self.writeDelay)
            guard !Task.isCancelled else { return }
            await self?.flush(repoID, store: store)
        }
    }

    @discardableResult
    private func enqueue(_ store: Store, _ operation: @escaping @Sendable (Store) async -> Void) -> Task<Void, Never> {
        let previous = queue
        let next = Task {
            await previous?.value
            await operation(store)
        }
        queue = next
        return next
    }

    private static func write(_ draft: WorkspaceDraft, to store: Store) async {
        let updated = try? await store.update(workspaceDraftFor: draft.repoID) { $0 = draft }
        guard updated == nil else { return }
        _ = try? await store.insert(draft)
    }
}
