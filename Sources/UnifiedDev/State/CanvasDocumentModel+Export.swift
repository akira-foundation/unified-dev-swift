import Foundation
import Core

extension CanvasDocumentModel {
    func exportFrames() {
        finishEditing()
        guard case .document(let held) = document else { return }
        do {
            var report = try CanvasExporter.export(document: held, path: path, worktree: worktree)
            report.onScreenOnly = warning != nil || keeper.hasStrandedEdits
            exportNotice = CanvasExportNotice.of(report, in: worktree)
        } catch {
            exportNotice = CanvasExportNotice.of(error)
        }
    }

    func dismissExportNotice() {
        exportNotice = nil
    }
}
