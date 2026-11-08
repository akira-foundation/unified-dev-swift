import Foundation
import Testing
@testable import Core

@Suite("Which canvas document an agent's tool may reach")
struct CanvasBridgeDocumentTests {
    private let worktree: URL

    init() throws {
        worktree = FileManager.default.temporaryDirectory.appending(path: "canvas-bridge-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: worktree, withIntermediateDirectories: true)
    }

    private func refusal<Value>(_ result: Result<Value, PaneRefusal>) -> String? {
        guard case .failure(let refused) = result else { return nil }
        return refused.sentence
    }

    @Test func aFileThatIsNotACanvasIsRefusedNamingTheTool() throws {
        try Data().write(to: worktree.appending(path: "a.png"))
        let answer = CanvasBridgeDocument.locate("a.png", worktree: worktree.path, tool: "canvas_read") { _ in false }
        #expect(refusal(answer) == "That file is not a canvas document. canvas_read works on files ending in .udcanvas.")
    }

    @Test func aDocumentThatIsNeitherOnDiskNorOpenIsRefused() {
        let answer = CanvasBridgeDocument.locate("gone.udcanvas", worktree: worktree.path, tool: "canvas_read") { _ in false }
        #expect(refusal(answer) == "That canvas document does not exist in this workspace.")
    }

    @Test func aDocumentOnlyOpenInATabIsStillReached() throws {
        let answer = CanvasBridgeDocument.locate("gone.udcanvas", worktree: worktree.path, tool: "canvas_read") { _ in true }
        #expect(try answer.get().hasSuffix("/gone.udcanvas"))
    }

    @Test func aPathOutOfTheWorkspaceIsRefused() {
        let answer = CanvasBridgeDocument.locate("/etc/x.udcanvas", worktree: worktree.path, tool: "canvas_read") { _ in true }
        #expect(refusal(answer)?.contains("not inside this workspace") == true)
    }

    @Test func aCorruptDocumentSaysWhyAndANewerOneSaysItsVersion() {
        let corrupt = CanvasBridgeDocument.readable(.corrupt("The problem is at frames."), doing: "read")
        let newer = CanvasBridgeDocument.readable(.newerVersion(99), doing: "drawn")
        #expect(refusal(corrupt) == "This canvas cannot be read: The problem is at frames.")
        #expect(refusal(newer) == "This canvas was saved as version 99, and this Unified Dev reads up to version \(CanvasDocument.currentVersion).")
    }

    @Test func aReadableDocumentComesBack() throws {
        let document = CanvasDocument()
        #expect(try CanvasBridgeDocument.readable(.document(document), doing: "read").get() == document)
    }

    @Test func aFrameNotInTheDocumentIsRefusedListingTheOnesThatAre() {
        let frame = CanvasFrame(id: CanvasFrameID("one"), name: "One", rect: CanvasRect(x: 0, y: 0, width: 10, height: 10))
        let missing = CanvasBridgeDocument.renderTarget(CanvasFrameID("x"), in: CanvasDocument(frames: [frame]))
        let empty = CanvasBridgeDocument.renderTarget(CanvasFrameID("x"), in: CanvasDocument())
        #expect(refusal(missing)?.contains("one") == true)
        #expect(refusal(empty)?.contains("none") == true)
    }

    @Test func aFrameAboveTheLimitIsRefusedWithItsSize() {
        let frame = CanvasFrame(id: CanvasFrameID("big"), name: "Big", rect: CanvasRect(x: 0, y: 0, width: 9_000, height: 10))
        let answer = CanvasBridgeDocument.renderTarget(frame.id, in: CanvasDocument(frames: [frame]))
        #expect(refusal(answer)?.contains("9000 by 10 points") == true)
        #expect(refusal(answer)?.contains("8192") == true)
    }

    @Test func aFrameInsideTheLimitGetsItsPlan() throws {
        let frame = CanvasFrame(id: CanvasFrameID("f"), name: "F", rect: CanvasRect(x: 0, y: 0, width: 4_096, height: 10))
        let target = try CanvasBridgeDocument.renderTarget(frame.id, in: CanvasDocument(frames: [frame])).get()
        #expect(target.frame == frame)
        #expect(target.plan.scale == 0.5)
    }
}
