import Core

extension AppModel {
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
