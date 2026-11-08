import SwiftUI
import Core

struct CanvasPaneView: View {
    @Bindable var model: WorkspaceModel
    var tab: CenterTab

    var body: some View {
        let revision = model.changesGeneration
        switch CanvasFile.showable(path: tab.path, worktree: model.workspace.path) {
        case .file(let absolute, _) where CanvasDocumentFile.isDocument(path: absolute):
            CanvasEditorView(model: model.canvasDocument(path: absolute), revision: revision)
                .id(tab.path)
        case .file(let absolute, _):
            DocumentPreviewView(
                path: absolute,
                worktree: model.workspace.path,
                revision: revision,
                openFile: open,
                opensLinkInside: { BrowserTab.staysInside($0) },
                openLinkInside: { BrowserTab.open($0, in: model) }
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
