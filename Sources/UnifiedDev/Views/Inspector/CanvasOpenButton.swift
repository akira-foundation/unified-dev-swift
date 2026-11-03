import SwiftUI
import Core

struct CanvasOpenButton: View {
    let model: WorkspaceModel
    let path: String

    var body: some View {
        if case .file(_, let relative) = CanvasFile.resolve(path: path, worktree: model.workspace.path) {
            Button {
                let tab = CenterTabStore.shared.showCanvas(path: relative, workspaceID: model.workspace.id)
                WorkspaceTabsStore.shared.reveal(.tool(tab.id), in: model, focusing: true)
            } label: {
                Image(systemName: PaneGlyph.canvas)
            }
            .buttonStyle(.borderless)
            .help("Open in Canvas")
            .accessibilityLabel("Open in Canvas")
        }
    }
}
