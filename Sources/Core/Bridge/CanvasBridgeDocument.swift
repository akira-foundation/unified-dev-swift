import Foundation

public struct CanvasRenderTarget: Sendable, Equatable {
    public let frame: CanvasFrame
    public let plan: CanvasRenderPlan
}

public enum CanvasBridgeDocument {
    public static func locate(
        _ path: String, worktree: String, tool: String, isOpen: (String) -> Bool
    ) -> Result<String, PaneRefusal> {
        let absolute: String
        switch CanvasFile.contained(path: path, worktree: worktree) {
        case .refused(let sentence): return .failure(PaneRefusal(sentence))
        case .file(let resolved, _): absolute = resolved
        }
        guard CanvasDocumentFile.isDocument(path: absolute) else {
            return .failure(PaneRefusal(
                "That file is not a canvas document. \(tool) works on files ending in .\(CanvasDocumentFile.fileExtension)."
            ))
        }
        guard isOpen(absolute) || FileManager.default.fileExists(atPath: absolute) else {
            return .failure(PaneRefusal("That canvas document does not exist in this workspace."))
        }
        return .success(absolute)
    }

    public static func readable(_ decoding: CanvasDocumentDecoding, doing verb: String) -> Result<CanvasDocument, PaneRefusal> {
        switch decoding {
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

    public static func renderTarget(_ frameID: CanvasFrameID, in document: CanvasDocument) -> Result<CanvasRenderTarget, PaneRefusal> {
        guard let frame = document.frames.first(where: { $0.id == frameID }) else {
            let known = document.frames.isEmpty ? "none" : CanvasFileText.list(document.frames.map(\.id.rawValue))
            return .failure(PaneRefusal(
                "There is no frame \(CanvasFileText.quoted(frameID.rawValue)) in this canvas. Its frames are: \(known). \(CanvasFileText.isFromFile)"
            ))
        }
        guard let plan = CanvasRenderPlan(frameSize: frame.rect.size) else {
            return .failure(PaneRefusal(
                "Frame \(CanvasFileText.quoted(frameID.rawValue)) is \(CanvasRenderPlan.points(frame.rect.size.width)) by \(CanvasRenderPlan.points(frame.rect.size.height)) points, "
                    + "and canvas_render draws frames up to \(CanvasRenderPlan.points(CanvasFrameSize.maximum)) points a side."
            ))
        }
        return .success(CanvasRenderTarget(frame: frame, plan: plan))
    }

    public static func couldNotFit(_ frameID: CanvasFrameID) -> String {
        "Unified Dev could not draw frame \(CanvasFileText.quoted(frameID.rawValue)) small enough to send."
    }
}
