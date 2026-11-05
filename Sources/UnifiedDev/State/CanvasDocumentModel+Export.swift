import Foundation
import Core

extension CanvasDocumentModel {
    func exportFrames() {
        guard case .document(let held) = document else { return }
        do {
            let report = try CanvasExporter.export(document: held, path: path, worktree: worktree)
            exportNotice = CanvasExportNotice.of(report, in: URL(filePath: worktree).resolvingSymlinksInPath().path)
        } catch {
            exportNotice = CanvasExportNotice.of(error)
        }
    }

    func dismissExportNotice() {
        exportNotice = nil
    }
}
