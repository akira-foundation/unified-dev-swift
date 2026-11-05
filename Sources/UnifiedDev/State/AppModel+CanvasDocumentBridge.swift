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

    private func canvasForBridge(
        _ path: String, in workspaceID: WorkspaceID, tool: String
    ) -> Result<CanvasDocumentModel, PaneRefusal> {
        guard let model = paneTarget(workspaceID) else { return .failure(PaneRefusal(Self.noWorkspaceForPane)) }
        let located = CanvasBridgeDocument.locate(path, worktree: model.workspace.path, tool: tool) {
            model.existingCanvasDocument(path: $0) != nil
        }
        return located.map { model.existingCanvasDocument(path: $0) ?? model.canvasDocument(path: $0) }
    }

    func readCanvasForBridge(_ path: String, in workspaceID: WorkspaceID) async -> CanvasReadOutcome {
        let canvas: CanvasDocumentModel
        switch canvasForBridge(path, in: workspaceID, tool: "canvas_read") {
        case .failure(let refusal): return .refused(refusal.sentence)
        case .success(let found): canvas = found
        }
        await canvas.reconcile()
        switch CanvasBridgeDocument.readable(canvas.document, doing: "read") {
        case .failure(let refusal): return .refused(refusal.sentence)
        case .success(let document):
            return .read(CanvasReadAnswer(
                document: document, measuredTextSize: CanvasTextMeasure.sizes(in: document), warning: canvas.warning?.heldAnswerWarning
            ))
        }
    }

    func editCanvasForBridge(
        _ path: String, operations: [CanvasOperation], in workspaceID: WorkspaceID
    ) async -> CanvasAgentEditOutcome {
        let canvas: CanvasDocumentModel
        switch canvasForBridge(path, in: workspaceID, tool: "canvas_edit") {
        case .failure(let refusal): return .refused(refusal.sentence)
        case .success(let found): canvas = found
        }
        await canvas.reconcile()
        return await canvas.applyAsAgent(operations)
    }

    func resolveCanvasCommentForBridge(
        _ order: CanvasCommentResolveOrder, in workspaceID: WorkspaceID
    ) async -> CanvasCommentResolveOutcome {
        let canvas: CanvasDocumentModel
        switch canvasForBridge(order.path, in: workspaceID, tool: CanvasCommentResolveToolName.resolve) {
        case .failure(let refusal): return .refused(refusal.sentence)
        case .success(let found): canvas = found
        }
        await canvas.reconcile()
        let handover = await paneTarget(workspaceID)?.canvasCommentHandover(of: order.commentID, in: canvas)
        return await canvas.resolveComment(order, handover: handover)
    }

    func renderCanvasForBridge(
        _ path: String, frame frameID: CanvasFrameID, in workspaceID: WorkspaceID
    ) async -> CanvasRenderOutcome {
        let canvas: CanvasDocumentModel
        switch canvasForBridge(path, in: workspaceID, tool: "canvas_render") {
        case .failure(let refusal): return .refused(refusal.sentence)
        case .success(let found): canvas = found
        }
        await canvas.reconcile()
        let document: CanvasDocument
        switch CanvasBridgeDocument.readable(canvas.document, doing: "drawn") {
        case .failure(let refusal): return .refused(refusal.sentence)
        case .success(let found): document = found
        }
        let target: CanvasRenderTarget
        switch CanvasBridgeDocument.renderTarget(frameID, in: document) {
        case .failure(let refusal): return .refused(refusal.sentence)
        case .success(let found): target = found
        }
        let frame = target.frame
        var skippedImages: [String] = []
        guard let fitted = target.plan.fit(draw: { scale in
            let picture = CanvasFrameRenderer.picture(
                frame: frame, document: document, documentPath: canvas.path, worktree: canvas.worktree, scale: scale
            )
            skippedImages = picture.skippedImages
            return picture.png
        }) else {
            return .refused(CanvasBridgeDocument.couldNotFit(frameID))
        }
        return .rendered(CanvasRenderedFrame(
            png: fitted.png, size: frame.rect.size, scale: fitted.scale,
            missingFonts: CanvasFrameRenderer.missingFonts(in: frame, of: document),
            skippedImages: skippedImages,
            warning: canvas.warning?.heldAnswerWarning
        ))
    }
}
