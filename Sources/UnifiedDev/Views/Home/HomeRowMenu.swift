import SwiftUI
import Core

struct HomeRowMenu: View {
    var row: HomeRow
    var onRename: (WorkspaceID) -> Void
    var onDelete: (Workspace) -> Void

    @Environment(AppModel.self) private var app

    private var workspace: Workspace { row.workspace }

    var body: some View {
        if row.isArchived {
            Button("Open") { app.openArchived(workspace) }
            Button("Restore Workspace") {
                Task { await app.restore(workspace) }
            }
            .disabled(app.restoring.contains(workspace.id))
            Divider()
            Button("Copy Branch Name") { Clipboard.copy(workspace.branch) }
            Divider()
            Button("Delete\u{2026}") { onDelete(workspace) }
        } else {
            WorkspaceMenuItems(workspace: workspace, onRename: onRename)
        }
    }
}
