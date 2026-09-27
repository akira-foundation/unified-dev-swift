import Foundation
import Observation
import Core

@MainActor
@Observable
final class SidebarPane {
    struct Shape: Equatable {
        var filter: SidebarFilter
        var showsHiddenProjects: Bool
    }

    struct ReorderNote: Equatable {
        var id = UUID()
        var sentence: String
    }

    private(set) var groups: [SidebarRepoGroup] = []
    private(set) var rows: [SidebarPaneRow] = []
    private(set) var workspaceIdentities: Set<WorkspaceID> = []
    private(set) var hasSettled = false
    private(set) var reorderNote: ReorderNote?
    var arrival = RowArrival<WorkspaceID>()

    var foldedProjects: [RepoID] {
        groups.filter(\.repo.collapsed).map(\.id)
    }

    var projectIdentities: Set<RepoID> {
        Set(groups.map(\.id))
    }

    var hiddenProjects: [RepoID] {
        groups.filter(\.repo.hidden).map(\.id)
    }

    func regroup(_ app: AppModel, shape: Shape, rescoped: Bool = false) {
        groups = SidebarRepoGroup.build(
            repos: app.repos,
            workspaces: app.workspaces,
            filter: shape.filter,
            showingHidden: shape.showsHiddenProjects
        )
        reflow(app, shape: shape)
        let ids = groups.flatMap { $0.workspaces.map(\.id) } + app.pendingWorkspaces.map(\.id)
        workspaceIdentities = Set(ids)
        if rescoped {
            arrival.adopt(ids)
        } else {
            arrival.absorb(ids)
        }
    }

    func reflow(_ app: AppModel, shape: Shape) {
        rows = SidebarPaneRow.rows(
            groups,
            crew: app.crew(of:),
            subagents: app.subagents(of:),
            pending: app.drawnPending(in:),
            showsDraft: app.showsDraft(in:)
        )
    }

    func draws(_ workspaceID: WorkspaceID) -> Bool {
        rows.contains { $0.drawnWorkspaceID == workspaceID }
    }

    func move(from: IndexSet, to: Int, in app: AppModel) {
        switch SidebarReorder.destination(rows: rows.map(\.identity), from: from, to: to) {
        case .nothing:
            break

        case .project(let id, let offset):
            let visible = groups.map(\.id)
            Task { await app.reorderProjects(id: id, visible: visible, to: offset) }

        case .workspace(let projectID, let offsets, let offset, let landedOutside):
            guard let group = groups.first(where: { $0.id == projectID }) else { return }
            if landedOutside { note("Kept in \(group.repo.name)") }
            Task {
                await app.reorderWorkspaces(
                    in: group.repo, visible: group.workspaces, from: offsets, to: offset
                )
            }
        }
    }

    func settle(isLoaded: Bool) async {
        hasSettled = false
        guard isLoaded else { return }
        try? await Task.sleep(for: .milliseconds(250))
        guard !Task.isCancelled else { return }
        hasSettled = true
    }

    func note(_ sentence: String) {
        reorderNote = ReorderNote(sentence: sentence)
    }

    func expireReorderNote() async {
        guard reorderNote != nil else { return }
        try? await Task.sleep(for: .seconds(2.4))
        guard !Task.isCancelled else { return }
        reorderNote = nil
    }
}
