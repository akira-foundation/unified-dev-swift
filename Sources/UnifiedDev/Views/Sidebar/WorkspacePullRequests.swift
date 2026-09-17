import SwiftUI
import Observation
import Core

@MainActor
@Observable
final class WorkspacePullRequests {
    static let shared = WorkspacePullRequests()

    static let refreshInterval = Duration.seconds(120)

    private static let maxAge = Duration.seconds(110)

    private var states: [WorkspaceID: PullRequestRefreshState] = [:]
    @ObservationIgnored private var generations: [WorkspaceID: UInt64] = [:]

    func failure(for workspaceID: WorkspaceID) -> GitHubReadFailure? { states[workspaceID]?.failure }

    func record(_ read: PullRequestRead, for workspaceID: WorkspaceID) {
        generations[workspaceID, default: 0] &+= 1
        var state = states[workspaceID] ?? PullRequestRefreshState()
        state.record(read)
        if states[workspaceID] != state { states[workspaceID] = state }
    }

    private var queue: Task<Void, Never> = Task {}

    func pullRequest(for workspaceID: WorkspaceID) -> PullRequest? {
        states[workspaceID]?.pullRequest
    }

    func set(_ pullRequest: PullRequest?, for workspaceID: WorkspaceID) {
        record(.current(pullRequest), for: workspaceID)
    }

    func forget(_ workspaceID: WorkspaceID) {
        generations[workspaceID, default: 0] &+= 1
        states[workspaceID] = nil
    }

    func track(_ workspace: Workspace, store: Store?) async {
        while !Task.isCancelled {
            await refresh(workspace, store: store)
            try? await Task.sleep(for: Self.refreshInterval)
        }
    }

    private func refresh(_ workspace: Workspace, store: Store?) async {
        guard workspace.hasDiff
            || workspace.pullRequestNumber != nil
            || states[workspace.id]?.pullRequest != nil else { return }

        let id = workspace.id
        let asked = workspace
        let generation = generations[id, default: 0]

        let previous = queue
        let lookup = Task { @MainActor in
            await previous.value
            guard !Task.isCancelled, self.generations[id, default: 0] == generation else { return }
            let read = await GitHubBridge.readPullRequest(for: asked, maxAge: Self.maxAge)
            guard !Task.isCancelled, self.generations[id, default: 0] == generation else { return }
            self.record(read, for: id)
            guard case .current(let fresh) = read else { return }
            guard let fresh else { return }
            await PullRequestNumber.record(fresh, for: asked, in: store)
        }
        queue = lookup
        await withTaskCancellationHandler { await lookup.value } onCancel: { lookup.cancel() }
    }
}
