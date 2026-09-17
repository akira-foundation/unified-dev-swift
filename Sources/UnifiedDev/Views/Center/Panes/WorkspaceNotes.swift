import SwiftUI
import Core

@MainActor
enum WorkspaceNotes {
    static func open(in model: WorkspaceModel) {
        let tab = CenterTabStore.shared.showNotes(workspaceID: model.workspace.id)
        WorkspaceTabsStore.shared.reveal(.tool(tab.id), in: model)
    }
}
