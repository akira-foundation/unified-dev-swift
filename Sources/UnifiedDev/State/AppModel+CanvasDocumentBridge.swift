import Foundation
import Core

extension AppModel {
    func flushCanvasDocuments() async {
        await flushCanvases(workspaceModels.values.flatMap(\.openCanvasDocuments))
    }

    func flushCanvasDocuments(of ids: some Collection<WorkspaceID>) async {
        await flushCanvases(ids.compactMap { workspaceModels[$0] }.flatMap(\.openCanvasDocuments))
    }

    private func flushCanvases(_ canvases: [CanvasDocumentModel]) async {
        await CanvasQuitFlush.run {
            let flushes = canvases.map { canvas in Task { await canvas.flush() } }
            for flush in flushes { await flush.value }
        }
    }

    var canvasQuitQuestion: CanvasQuitQuestion? {
        let standing = canvasStanding(of: workspaceModels.values.flatMap(\.openCanvasDocuments))
        return CanvasQuitQuestion(stranded: standing.stranded, copiesOfOwnerWork: standing.copies)
    }

    func canvasArchiveQuestion(of ids: some Collection<WorkspaceID>) -> CanvasArchiveQuestion? {
        let standing = canvasStanding(of: ids.compactMap { workspaceModels[$0] }.flatMap(\.openCanvasDocuments))
        return CanvasArchiveQuestion(stranded: standing.stranded, copiesOfOwnerWork: standing.copies)
    }

    private func canvasStanding(of canvases: [CanvasDocumentModel]) -> (stranded: [String], copies: [String]) {
        (canvases.filter(\.hasStrandedEdits).map(\.path), canvases.flatMap(\.copiesHoldingOwnerWork))
    }

    func readCanvasForBridge(_ path: String, in workspaceID: WorkspaceID) async -> CanvasReadOutcome {
        guard let model = paneTarget(workspaceID) else { return .refused(Self.noWorkspaceForPane) }
        let absolute: String
        switch CanvasFile.resolve(path: path, worktree: model.workspace.path) {
        case .refused(let sentence): return .refused(sentence)
        case .file(let resolved, _): absolute = resolved
        }
        guard CanvasDocumentFile.isDocument(path: absolute) else {
            return .refused("That file is not a canvas document. canvas_read reads files ending in .\(CanvasDocumentFile.fileExtension).")
        }
        let canvas = model.canvasDocument(path: absolute)
        await canvas.reconcile()
        switch canvas.document {
        case .document(let document):
            return .read(CanvasReadAnswer(document: document, measuredTextSize: CanvasTextMeasure.sizes(in: document)))
        case .corrupt(let reason):
            return .refused("This canvas cannot be read: \(reason)")
        case .newerVersion(let version):
            return .refused(
                "This canvas was saved as version \(version), and this Unified Dev reads up to version \(CanvasDocument.currentVersion)."
            )
        }
    }
}
