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
