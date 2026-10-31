import SwiftUI
import Core

struct CanvasPaneView: View {
    @Bindable var model: WorkspaceModel
    var tab: CenterTab

    var body: some View {
        let revision = model.changesGeneration
        switch CanvasFile.resolve(path: tab.path, worktree: model.workspace.path) {
        case .file(let absolute, _):
            DocumentPreviewView(
                path: absolute,
                worktree: model.workspace.path,
                revision: revision,
                openFile: open
            )
            .id(tab.path)
        case .refused:
            ContentUnavailableView(
                "Nothing to show",
                systemImage: PaneGlyph.canvas,
                description: Text("\(tab.path) is not a file this canvas can show.")
            )
        }
    }

    private func open(_ absolute: String) {
        let worktree = model.workspace.path
        guard case .file(_, let relative) = CanvasFile.resolve(path: absolute, worktree: worktree) else {
            FileReview.openInNewTab(path: DocumentPreview.worktreePath(of: absolute, worktree: worktree), in: model)
            return
        }
        CenterTabStore.shared.showCanvas(path: relative, workspaceID: model.workspace.id)
    }
}
