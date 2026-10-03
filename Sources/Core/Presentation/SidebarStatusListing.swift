import Foundation

public struct SidebarStatusListing: Equatable, Sendable {
    public struct Section: Equatable, Sendable {
        public var group: SidebarStatusGroup
        public var workspaces: [Workspace]
        public var pending: [PendingWorkspace]

        public init(group: SidebarStatusGroup, workspaces: [Workspace], pending: [PendingWorkspace] = []) {
            self.group = group
            self.workspaces = workspaces
            self.pending = pending
        }

        public var count: Int { workspaces.count + pending.count }
    }

    public var drafts: [RepoID]
    public var sections: [Section]

    public init(drafts: [RepoID] = [], sections: [Section]) {
        self.drafts = drafts
        self.sections = sections
    }

    public static let empty = SidebarStatusListing(sections: [])

    public var arrangement: [String] {
        drafts.map { "draft:" + $0.rawValue } + sections.flatMap { section in
            section.workspaces.map { section.group.rawValue + ":" + $0.id.rawValue }
                + section.pending.map { section.group.rawValue + ":" + $0.id.rawValue }
        }
    }

    public static func build(
        workspaces: [Workspace],
        holding: WorkspaceID? = nil,
        pending: [PendingWorkspace] = [],
        drafts: [RepoID] = [],
        status: (Workspace) -> WorkspaceStatus
    ) -> SidebarStatusListing {
        var byGroup: [SidebarStatusGroup: [Workspace]] = [:]
        for workspace in workspaces {
            let unread = workspace.unread || workspace.id == holding
            byGroup[SidebarStatusGroup.of(status(workspace), unread: unread), default: []].append(workspace)
        }

        let sections = SidebarStatusGroup.allCases.compactMap { group -> Section? in
            let rows = byGroup[group] ?? []
            let waiting = group == .working ? pending : []
            guard !rows.isEmpty || !waiting.isEmpty else { return nil }
            return Section(
                group: group,
                workspaces: group.ranksByRecency ? byRecency(rows) : rows,
                pending: waiting
            )
        }
        return SidebarStatusListing(drafts: drafts, sections: sections)
    }

    private static func byRecency(_ workspaces: [Workspace]) -> [Workspace] {
        workspaces.enumerated()
            .sorted { lhs, rhs in
                if lhs.element.lastActivityAt != rhs.element.lastActivityAt {
                    return lhs.element.lastActivityAt > rhs.element.lastActivityAt
                }
                return lhs.offset < rhs.offset
            }
            .map(\.element)
    }
}
