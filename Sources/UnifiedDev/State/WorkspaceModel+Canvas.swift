import Core

extension WorkspaceModel {
    func canvasDocument(path: String) -> CanvasDocumentModel {
        if let existing = canvasDocuments[path] { return existing }
        let created = CanvasDocumentModel(path: path, worktree: workspace.path)
        canvasDocuments[path] = created
        return created
    }
}
