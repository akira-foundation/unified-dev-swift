import Foundation
import Core

extension CanvasDocumentModel {
    func exportFrames() {
        finishEditing()
        guard case .document(let held) = document else { return }
        do {
            var report = try CanvasExporter.export(document: held, path: path, worktree: worktree)
            report.onScreenOnly = warning != nil || keeper.hasStrandedEdits
            notice = CanvasExportNotice.of(report, in: worktree)
        } catch {
            notice = CanvasExportNotice.of(error)
        }
    }

    func dismissNotice() {
        notice = nil
    }

    func addStroke(_ element: CanvasElement, reduced: Bool) {
        guard let outcome = apply([.addElement(element)]) else { return }
        if case .invalid(let reason) = outcome {
            notice = CanvasStrokeNotice.refused(reason)
            return
        }
        if reduced { notice = CanvasStrokeNotice.reduced() }
    }
}
