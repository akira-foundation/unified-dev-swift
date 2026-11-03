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
        if latest != document { adopt(latest) }
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
