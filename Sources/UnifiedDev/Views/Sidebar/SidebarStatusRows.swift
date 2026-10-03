import Core

enum SidebarStatusRows {
    static func rows(
        listing: SidebarStatusListing,
        projectName: (RepoID) -> String,
        folded: Set<SidebarStatusGroup>,
        crew: (WorkspaceID) -> [CrewRow],
        subagents: (WorkspaceID) -> [SubagentRow]
    ) -> [SidebarPaneRow] {
        var rows: [SidebarPaneRow] = listing.drafts.map { .draft($0) }
        for section in listing.sections {
            let isFolded = folded.contains(section.group)
            rows.append(.statusHeading(section.group, count: section.count, isFolded: isFolded))
            guard !isFolded else { continue }

            for workspace in section.workspaces {
                rows.append(.workspace(workspace, projectName: projectName(workspace.repoID)))
                rows.append(contentsOf: crew(workspace.id).map {
                    .crew($0, workspaceID: workspace.id, repoID: workspace.repoID)
                })
                rows.append(contentsOf: subagents(workspace.id).map {
                    .subagent($0, workspaceID: workspace.id, repoID: workspace.repoID)
                })
            }
            rows.append(contentsOf: section.pending.map { .pending($0) })
        }
        return rows
    }
}
