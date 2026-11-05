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
        let absolute: String
        switch CanvasFile.contained(path: path, worktree: model.workspace.path) {
        case .refused(let sentence): return .failure(PaneRefusal(sentence))
        case .file(let resolved, _): absolute = resolved
        }
        guard CanvasDocumentFile.isDocument(path: absolute) else {
            return .failure(PaneRefusal(
                "That file is not a canvas document. \(tool) works on files ending in .\(CanvasDocumentFile.fileExtension)."
            ))
        }
        if let open = model.existingCanvasDocument(path: absolute) { return .success(open) }
        guard FileManager.default.fileExists(atPath: absolute) else {
            return .failure(PaneRefusal("That canvas document does not exist in this workspace."))
        }
        return .success(model.canvasDocument(path: absolute))
    }

    private func readableCanvas(_ canvas: CanvasDocumentModel, doing verb: String) -> Result<CanvasDocument, PaneRefusal> {
        switch canvas.document {
        case .document(let document):
            return .success(document)
        case .corrupt(let reason):
            return .failure(PaneRefusal("This canvas cannot be \(verb): \(reason)"))
        case .newerVersion(let version):
            return .failure(PaneRefusal(
                "This canvas was saved as version \(version), and this Unified Dev reads up to version \(CanvasDocument.currentVersion)."
            ))
        }
    }

    func readCanvasForBridge(_ path: String, in workspaceID: WorkspaceID) async -> CanvasReadOutcome {
        let canvas: CanvasDocumentModel
        switch canvasForBridge(path, in: workspaceID, tool: "canvas_read") {
        case .failure(let refusal): return .refused(refusal.sentence)
        case .success(let found): canvas = found
        }
        await canvas.reconcile()
        switch readableCanvas(canvas, doing: "read") {
        case .failure(let refusal): return .refused(refusal.sentence)
        case .success(let document):
            return .read(CanvasReadAnswer(document: document, measuredTextSize: CanvasTextMeasure.sizes(in: document)))
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
        switch readableCanvas(canvas, doing: "drawn") {
        case .failure(let refusal): return .refused(refusal.sentence)
        case .success(let found): document = found
        }
        guard let frame = document.frames.first(where: { $0.id == frameID }) else {
            let known = document.frames.map(\.id.rawValue).joined(separator: ", ")
            return .refused("There is no frame '\(frameID.rawValue)' in this canvas. Its frames are: \(known.isEmpty ? "none" : known).")
        }
        guard let plan = CanvasRenderPlan(frameSize: frame.rect.size) else {
            return .refused(
                "Frame '\(frameID.rawValue)' is \(CanvasRenderPlan.points(frame.rect.size.width)) by \(CanvasRenderPlan.points(frame.rect.size.height)) points, "
                    + "and canvas_render draws frames up to \(CanvasRenderPlan.points(CanvasRenderPlan.largestFrameSide)) points a side."
            )
        }
        guard let fitted = plan.fit(draw: { scale in
            CanvasFrameRenderer.png(
                frame: frame, document: document, documentPath: canvas.path, worktree: canvas.worktree, scale: scale
            )
        }) else {
            return .refused("Unified Dev could not draw frame '\(frameID.rawValue)' small enough to send.")
        }
        return .rendered(CanvasRenderedFrame(
            png: fitted.png, size: frame.rect.size, scale: fitted.scale,
            missingFonts: CanvasFrameRenderer.missingFonts(in: frame, of: document)
        ))
    }
}
