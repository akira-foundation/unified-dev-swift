import Core

extension WorkspaceModel {
    func canvasDocument(path: String) -> CanvasDocumentModel {
        if let existing = canvasDocuments[path] { return existing }
        let created = CanvasDocumentModel(path: path, worktree: workspace.path)
        canvasDocuments[path] = created
        created.onCommentsNeedSettling = { [weak self, weak created] in
            guard let self, let created else { return }
            Task { await self.settleCanvasComments(in: created) }
        }
        created.commentCourier = canvasCommentCourier(for: created)
        created.settleOpening()
        return created
    }

    func existingCanvasDocument(path: String) -> CanvasDocumentModel? { canvasDocuments[path] }

    var openCanvasDocuments: [CanvasDocumentModel] { Array(canvasDocuments.values) }

    func reconcileCanvasDocuments() {
        for canvas in canvasDocuments.values {
            canvas.requestReconcile()
        }
    }
}
