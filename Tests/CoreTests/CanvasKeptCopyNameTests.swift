import Foundation
import Testing
@testable import Core

@Suite("A kept copy of a canvas is a canvas", .scratchDirectory)
struct CanvasKeptCopyNameTests {
    private func worktree() throws -> String {
        let root = FileManager.default.temporaryDirectory.appending(path: "canvas-copy-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root.resolvingSymlinksInPath().path
    }

    @Test func theCopyIsNamedSoTheAppAcceptsIt() {
        let path = CanvasDocumentFile.backupPath(for: "/w/canvases/c.udcanvas", at: Date(timeIntervalSince1970: 0))
        #expect(path == "/w/canvases/c.backup-19700101T000000Z.udcanvas")
        #expect(CanvasDocumentFile.isDocument(path: path))
        #expect(CanvasFile.accepts(path: path))
    }

    @Test func aCopyWrittenBesideACanvasOpensThroughTheSameDoor() throws {
        let root = try worktree()
        defer { try? FileManager.default.removeItem(atPath: root) }
        let document = CanvasDocument(frames: [CanvasFrame(name: "Mine", rect: CanvasRect(x: 0, y: 0, width: 9, height: 9))])
        let copy = try CanvasDocumentFile.writeBackup(
            try CanvasDocumentCodec.encode(document), beside: root + "/deck.udcanvas", at: Date(timeIntervalSince1970: 0)
        )
        guard case .file(let absolute, _) = CanvasFile.resolve(path: copy, worktree: root) else {
            Issue.record("the copy did not resolve: \(CanvasFile.resolve(path: copy, worktree: root))")
            return
        }
        let keeper = CanvasDocumentKeeper(opening: CanvasDiskWorker.read(absolute))
        #expect(keeper.document == .document(document))
    }

    @Test func aCopyOpenedOnItsOwnAsksNoLossQuestion() throws {
        let root = try worktree()
        defer { try? FileManager.default.removeItem(atPath: root) }
        let copy = try CanvasDocumentFile.writeBackup(
            try CanvasDocumentCodec.encode(CanvasDocument()), beside: root + "/deck.udcanvas", at: Date(timeIntervalSince1970: 0)
        )
        let keeper = CanvasDocumentKeeper(opening: CanvasDiskWorker.read(copy))
        #expect(keeper.warning == nil)
        #expect(!keeper.hasStrandedEdits)
        #expect(keeper.copiesHoldingOwnerWork.isEmpty)
        #expect(CanvasQuitQuestion(stranded: [], copiesOfOwnerWork: keeper.copiesHoldingOwnerWork) == nil)
    }

    @Test func aCopyOfACopyIsStillACanvas() {
        let first = CanvasDocumentFile.backupPath(for: "/w/c.udcanvas", at: Date(timeIntervalSince1970: 0))
        let second = CanvasDocumentFile.backupPath(for: first, at: Date(timeIntervalSince1970: 1))
        #expect(CanvasFile.accepts(path: second))
        #expect(second != first)
    }
}
