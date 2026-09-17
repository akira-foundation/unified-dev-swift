import SwiftUI
import Core

struct SidebarWorkspaceRow: View {
    var workspace: Workspace
    var arrival: RowArrival<WorkspaceID>
    var projectName: String
    @Binding var renaming: WorkspaceID?
    @Binding var archivePresentation: SidebarArchivePresentation

    @Environment(AppModel.self) private var app

    @State private var anchor = HoverCardAnchor()
    private typealias ArchiveSource = SidebarArchivePresentation.Source

    private var isArchiveActive: Bool {
        archivePresentation.workspaceID == workspace.id
            && (archivePresentation.request != nil || archivePresentation.isRequesting)
    }

    var body: some View {
        WorkspaceRow(
            workspace: workspace,
            isRunning: app.isRunning(workspace),
            isAwaitingPermission: app.isAwaitingPermission(workspace),
            renaming: $renaming,
            onArchive: confirmRowArchive,
            onMenuArchive: { archive(from: .menu) },
            isArchiveActive: isArchiveActive,
            archiveRequest: archiveBinding(for: .button),
            menuArchiveRequest: archiveBinding(for: .menu),
            onConfirmArchive: confirmArchive
        )
        .arrivingRow(arrival.isArriving(workspace.id))
        .padding(.leading, SidebarMetrics.rowIndent)
        .accessibilityCustomContent(Text("Project"), Text(projectName), importance: .high)
        .background { HoverCardAnchorReader(anchor: anchor) }
        .onHoverChange { inside in
            if inside {
                WorkspaceHoverCardPresenter.shared.pointerEntered(
                    .workspaceRow(workspace.id),
                    card: hoverCard,
                    anchor: { anchor.screenFrame }
                )
            } else {
                WorkspaceHoverCardPresenter.shared.pointerExited(.workspaceRow(workspace.id))
            }
        }
        .onAppear { archivePresentation.rowAppeared(workspace.id) }
        .onDisappear {
            archivePresentation.rowDisappeared(workspace.id, isArchiving: app.isArchiving(workspace.id))
            WorkspaceHoverCardPresenter.shared.pointerExited(.workspaceRow(workspace.id))
        }
        .contextMenu {
            WorkspaceMenuItems(workspace: workspace, onArchive: { archive(from: .row) }) {
                renaming = $0
            }
        }
        .archiveConfirmation(archiveBinding(for: .row), arrowEdge: .leading, onConfirm: confirmArchive)
    }

    private func confirmRowArchive(_ workspace: Workspace) {
        archive(from: .button, alwaysConfirm: true)
    }

    private func archiveBinding(for source: ArchiveSource) -> Binding<ArchiveRequest?> {
        Binding(
            get: {
                guard archivePresentation.workspaceID == workspace.id,
                      archivePresentation.source == source else { return nil }
                return archivePresentation.request
            },
            set: { request in
                guard request == nil, archivePresentation.workspaceID == workspace.id,
                      archivePresentation.source == source else { return }
                archivePresentation.dismissRequest()
            }
        )
    }

    private func archive(from source: ArchiveSource, alwaysConfirm: Bool = false) {
        let generation = beginArchive(from: source)
        Task {
            defer { archivePresentation.finish(generation: generation) }
            await app.archive(workspace, alwaysConfirm: alwaysConfirm) { request in
                archivePresentation.present(request, generation: generation)
            }
        }
    }

    private func confirmArchive(_ request: ArchiveRequest) {
        let generation = beginArchive(from: archivePresentation.source)
        Task {
            defer { archivePresentation.finish(generation: generation) }
            await app.confirmArchive(request) { fresh in
                archivePresentation.present(fresh, generation: generation)
            }
        }
    }

    private func beginArchive(from source: ArchiveSource) -> UUID {
        WorkspaceHoverCardPresenter.shared.pointerExited(.workspaceRow(workspace.id))
        return archivePresentation.begin(workspaceID: workspace.id, source: source)
    }

    private func hoverCard() -> WorkspaceHoverCard? {
        guard renaming != workspace.id, !isArchiveActive else { return nil }
        return WorkspaceHoverCard.make(
            workspace: workspace,
            isRunning: app.isRunning(workspace),
            isAwaitingPermission: app.isAwaitingPermission(workspace),
            pullRequest: WorkspacePullRequests.shared.pullRequest(for: workspace.id)
        )
    }
}

struct SidebarEmptyNoticeRow: View {
    var isFiltered: Bool
    var body: some View {
        Label {
            Text(isFiltered ? "Nothing matches the filter" : "No workspaces yet")
                .foregroundStyle(Palette.textTertiary)
        } icon: {
            Color.clear
        }
        .labelStyle(SidebarRowLabelStyle())
        .padding(.leading, SidebarMetrics.rowIndent)
    }
}
