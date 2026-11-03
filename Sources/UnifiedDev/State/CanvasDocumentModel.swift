import Foundation
import ImageIO
import Observation
import Core

@MainActor
@Observable
final class CanvasDocumentModel {
    let path: String
    let worktree: String

    private(set) var session: CanvasDocumentSession?
    private var refusal: CanvasDocumentDecoding?

    var document: CanvasDocumentDecoding {
        if let session { return .document(session.document) }
        return refusal ?? .corrupt("This canvas has not been read.")
    }

    init(path: String, worktree: String) {
        self.path = path
        self.worktree = worktree
        adopt(Self.read(path))
    }

    func reload() {
        let latest = Self.read(path)
        if let session, !session.shouldReload(from: latest) { return }
        if latest != document { adopt(latest) }
    }

    @discardableResult
    func apply(_ operations: [CanvasOperation]) -> CanvasEditOutcome? {
        guard let outcome = session?.apply(operations, by: .owner) else { return nil }
        switch outcome {
        case .applied: break
        case .conflict(let conflicts): Log.canvas.error("canvas edit conflicted on \(conflicts.map(\.target), privacy: .public)")
        case .invalid(let reason): Log.canvas.error("canvas edit refused: \(reason, privacy: .public)")
        }
        return outcome
    }

    func update(_ build: (CanvasDocument) -> [CanvasOperation]) {
        guard let current = session?.document else { return }
        let operations = build(current)
        if !operations.isEmpty { apply(operations) }
    }

    func beginEditing(_ element: CanvasElementID) {
        session?.beginEditing(element)
    }

    func addImage(from source: URL, in frameID: CanvasFrameID) async {
        let documentPath = path
        let imported = await Task.detached { () -> (path: String, size: CanvasSize)? in
            guard let relative = try? CanvasImageImport.copy(source.path, beside: documentPath) else { return nil }
            return (relative, Self.pixelSize(of: source))
        }.value
        guard let imported, let frame = session?.document.frames.first(where: { $0.id == frameID }) else {
            Log.canvas.error("canvas image import failed for \(source.lastPathComponent, privacy: .public)")
            return
        }
        let size = CanvasImageImport.fittedSize(of: imported.size, in: frame.rect.size)
        let rect = CanvasRect(
            x: (frame.rect.size.width - size.width) / 2,
            y: (frame.rect.size.height - size.height) / 2,
            width: size.width,
            height: size.height
        )
        apply([.addElement(CanvasElement(frameID: frameID, rect: rect, kind: .image(path: imported.path)))])
    }

    nonisolated private static func pixelSize(of url: URL) -> CanvasSize {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Double,
              let height = properties[kCGImagePropertyPixelHeight] as? Double else {
            return CanvasSize(width: 0, height: 0)
        }
        return CanvasSize(width: width, height: height)
    }

    private func adopt(_ decoding: CanvasDocumentDecoding) {
        switch decoding {
        case .document(let document):
            session = CanvasDocumentSession(document: document)
            refusal = nil
        case .corrupt, .newerVersion:
            session = nil
            refusal = decoding
        }
    }

    private static func read(_ path: String) -> CanvasDocumentDecoding {
        do {
            return try CanvasDocumentFile.read(at: path)
        } catch {
            return .corrupt(error.localizedDescription)
        }
    }
}
