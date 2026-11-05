import Foundation
import Core

extension AppModel {
    func startTrackingPullRequests() {
        pullRequestTrackTask?.cancel()
        pullRequestTrackTask = Task { [weak self] in
            var schedule = PullRequestPollSchedule()
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(PullRequestPollSchedule.tick))
                guard let self else { return }
                await self.askDuePullRequests(&schedule)
            }
        }
    }

    private func askDuePullRequests(_ schedule: inout PullRequestPollSchedule) async {
        let tracker = WorkspacePullRequests.shared
        let rows = workspaces.filter { !isArchiving($0.id) }.map { workspace in
            PullRequestPollSchedule.Row(
                workspace,
                hasReadPullRequest: tracker.pullRequest(for: workspace.id) != nil,
                isDrawn: tracker.isDrawn(workspace.id)
            )
        }
        for id in schedule.due(rows: rows, now: Date()) {
            guard !Task.isCancelled else { return }
            guard !isArchiving(id), let workspace = workspaces.first(where: { $0.id == id }) else { continue }
            await tracker.refresh(workspace, store: store)
        }
    }
}
