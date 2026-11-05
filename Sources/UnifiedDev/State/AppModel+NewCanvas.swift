import Foundation
import Core

extension AppModel {
    func newCanvas() {
        guard let workspace = selectedWorkspace else { return }
        let worktree = workspace.path
        let folder = (worktree as NSString).appendingPathComponent(CanvasDocumentFile.folder)
        let names = (try? FileManager.default.contentsOfDirectory(atPath: folder)) ?? []
        let existing = Set(names.map { "\(CanvasDocumentFile.folder)/\($0)" })
        let wanted = CanvasDocumentFile.nextName(in: existing)
        guard case .file(_, let relative) = CanvasFile.resolveCreating(path: wanted, worktree: worktree) else { return }
        let model = self.model(for: workspace)
        let tab = CenterTabStore.shared.showCanvas(path: relative, workspaceID: workspace.id)
        WorkspaceTabsStore.shared.reveal(.tool(tab.id), in: model, focusing: true)
    }
}
