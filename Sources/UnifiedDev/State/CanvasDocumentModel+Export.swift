import Foundation
import Core

extension CanvasDocumentModel {
    func exportFrames() {
        finishEditing()
        guard case .document(let held) = document else { return }
        do {
            var report = try CanvasExporter.export(document: held, path: path, worktree: worktree)
            report.onScreenOnly = warning != nil || keeper.hasStrandedEdits
            exportNotice = CanvasNotice.of(report, in: worktree)
        } catch {
            exportNotice = CanvasNotice.of(error)
        }
    }

    func dismissExportNotice() {
        exportNotice = nil
    }

    func dismissStrokeNotice() {
        strokeNotice = nil
    }

    func addStroke(_ element: CanvasElement, reduced: Bool) -> Bool {
        guard let outcome = apply([.addElement(element)]) else { return false }
        var refusal: String?
        if case .invalid(let reason) = outcome { refusal = reason }
        strokeNotice = CanvasStrokeNotice.after(refusal: refusal, reduced: reduced)
        return refusal != nil
    }
}
