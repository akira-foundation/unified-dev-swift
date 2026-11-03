import Observation
import Core

@MainActor
@Observable
final class CanvasDocumentModel {
    let path: String
    let worktree: String

    private(set) var document: CanvasDocumentDecoding

    init(path: String, worktree: String) {
        self.path = path
        self.worktree = worktree
        document = Self.read(path)
    }

    func reload() {
        let latest = Self.read(path)
        if latest != document { document = latest }
    }

    private static func read(_ path: String) -> CanvasDocumentDecoding {
        do {
            return try CanvasDocumentFile.read(at: path)
        } catch {
            return .corrupt(error.localizedDescription)
        }
    }
}
