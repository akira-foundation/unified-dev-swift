import SwiftUI
import Observation
import Core

@MainActor
@Observable
final class WorkspacePullRequests {
    static let shared = WorkspacePullRequests()

    private static let maxAge = Duration.seconds(110)

    private var states: [WorkspaceID: PullRequestRefreshState] = [:]
    @ObservationIgnored private var generations: [WorkspaceID: UInt64] = [:]
    @ObservationIgnored private var drawnRows: [WorkspaceID: Int] = [:]
    @ObservationIgnored var onCurrentRead: (@MainActor (WorkspaceID, PullRequest) async -> Void)?

    func failure(for workspaceID: WorkspaceID) -> GitHubReadFailure? { states[workspaceID]?.visibleFailure }

    func dismissFailure(for workspaceID: WorkspaceID) {
        states[workspaceID]?.dismissFailure()
    }

    func record(_ read: PullRequestRead, for workspaceID: WorkspaceID) {
        generations[workspaceID, default: 0] &+= 1
        var state = states[workspaceID] ?? PullRequestRefreshState()
        state.record(read)
        if states[workspaceID] != state { states[workspaceID] = state }
        if case .current(let pullRequest?) = read, let onCurrentRead {
            Task { await onCurrentRead(workspaceID, pullRequest) }
        }
    }

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

    func isDrawn(_ workspaceID: WorkspaceID) -> Bool {
        drawnRows[workspaceID, default: 0] > 0
    }

    func holdDrawn(_ workspaceID: WorkspaceID) async {
        drawnRows[workspaceID, default: 0] += 1
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(3600))
        }
        drawnRows[workspaceID, default: 1] -= 1
    }

    func refresh(_ workspace: Workspace, store: Store?) async {
        let id = workspace.id
        let generation = generations[id, default: 0]
        let read = await GitHubBridge.readPullRequest(for: workspace, maxAge: Self.maxAge)
        guard !Task.isCancelled, generations[id, default: 0] == generation else { return }
        record(read, for: id)
        guard case .current(let fresh?) = read else { return }
        await PullRequestNumber.record(fresh, for: workspace, in: store)
    }
}
