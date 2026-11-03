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
    ) -> Result<CanvasDocumentModel, CanvasBridgeRefusal> {
        guard let model = paneTarget(workspaceID) else {
            return .failure(CanvasBridgeRefusal(sentence: Self.noWorkspaceForPane))
        }
        switch CanvasFile.resolve(path: path, worktree: model.workspace.path) {
        case .refused(let sentence):
            return .failure(CanvasBridgeRefusal(sentence: sentence))
        case .file(let absolute, _):
            guard CanvasDocumentFile.isDocument(path: absolute) else {
                return .failure(CanvasBridgeRefusal(
                    sentence: "That file is not a canvas document. \(tool) works on files ending in .\(CanvasDocumentFile.fileExtension)."
                ))
            }
            return .success(model.canvasDocument(path: absolute))
        }
    }

    private func readableCanvas(_ canvas: CanvasDocumentModel, doing verb: String) -> Result<CanvasDocument, CanvasBridgeRefusal> {
        switch canvas.document {
        case .document(let document):
            return .success(document)
        case .corrupt(let reason):
            return .failure(CanvasBridgeRefusal(sentence: "This canvas cannot be \(verb): \(reason)"))
        case .newerVersion(let version):
            return .failure(CanvasBridgeRefusal(
                sentence: "This canvas was saved as version \(version), and this Unified Dev reads up to version \(CanvasDocument.currentVersion)."
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
    ) async -> CanvasEditOutcome {
        let canvas: CanvasDocumentModel
        switch canvasForBridge(path, in: workspaceID, tool: "canvas_edit") {
        case .failure(let refusal): return .invalid(refusal.sentence)
        case .success(let found): canvas = found
        }
        await canvas.reconcile()
        if case .failure(let refusal) = readableCanvas(canvas, doing: "edited") { return .invalid(refusal.sentence) }
        if let warning = canvas.warning, warning.refusesAgentEdits {
            return .invalid(
                "Nothing was changed. \(warning.title) in the tab, and the person has to settle that first. \(warning.message)"
            )
        }
        guard let outcome = canvas.apply(operations, by: .agent) else {
            return .invalid("This canvas could not be edited right now. Read it with canvas_read and try again.")
        }
        await canvas.settle()
        return outcome
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
                "Frame '\(frameID.rawValue)' is \(Int(frame.rect.size.width)) by \(Int(frame.rect.size.height)) points, "
                    + "and canvas_render draws frames up to \(Int(CanvasRenderPlan.largestFrameSide)) points a side."
            )
        }
        guard let png = CanvasFrameRenderer.png(
            frame: frame, document: document, documentPath: canvas.path, worktree: canvas.worktree, scale: plan.scale
        ) else {
            return .refused("Unified Dev could not draw frame '\(frameID.rawValue)'.")
        }
        return .rendered(CanvasRenderedFrame(
            png: png, size: frame.rect.size, missingFonts: CanvasFrameRenderer.missingFonts(in: frame, of: document)
        ))
    }
}

struct CanvasBridgeRefusal: Error {
    let sentence: String
}
