import Foundation

public enum SearchPanelResting {
    public static let waitingCap = 5

    public static let recentCap = 5

    public static func build(
        workspaces: [Workspace],
        repos: [Repo],
        activity: HomeActivity,
        reach: SearchPanelReach = .live
    ) -> SearchPanelListing {
        var byID: [RepoID: Repo] = [:]
        byID.reserveCapacity(repos.count)
        for repo in repos { byID[repo.id] = repo }

        let reachable = Set(reach.projects(repos).map(\.id))
        let workspaces = workspaces.filter { reachable.contains($0.repoID) }

        let recent = workspaces.sorted { $0.lastActivityAt > $1.lastActivityAt }

        let waiting = recent
            .compactMap { workspace -> SearchPanelWorkspaceHit? in
                guard let reason = reason(for: workspace, activity: activity) else { return nil }
                return SearchPanelWorkspaceHit(
                    workspace: workspace, repo: byID[workspace.repoID], waiting: reason
                )
            }
            .prefix(waitingCap)

        let taken = Set(waiting.map(\.id))
        let opened = recent
            .filter { !taken.contains($0.id) }
            .prefix(recentCap)
            .map { SearchPanelWorkspaceHit(workspace: $0, repo: byID[$0.repoID]) }

        var sections: [SearchPanelSection] = []
        if !waiting.isEmpty {
            sections.append(
                SearchPanelSection(
                    id: "waiting", title: "Waiting on you",
                    rows: waiting.map { .workspace($0) }
                )
            )
        }
        if !opened.isEmpty {
            sections.append(
                SearchPanelSection(
                    id: "recent", title: sections.isEmpty ? "Recent" : "Recently open",
                    rows: opened.map { .workspace($0) }
                )
            )
        }
        return SearchPanelListing(
            sections: sections,
            summary: SearchPanelSummary.resting(
                shown: waiting.count + opened.count, of: workspaces.count
            ),
            nothing: sections.isEmpty ? .nothingYet : nil
        )
    }

    public static func reason(
        for workspace: Workspace, activity: HomeActivity
    ) -> SearchPanelWaiting? {
        guard activity.needsYou(workspace) else { return nil }
        return activity.waiting.contains(workspace.id) ? .askedAQuestion : .turnFinished
    }
}
