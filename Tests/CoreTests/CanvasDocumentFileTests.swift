import Foundation
import Testing
@testable import Core

@Suite("Canvas document file", .scratchDirectory)
struct CanvasDocumentFileTests {
    private func worktree() throws -> (given: String, root: String) {
        let given = TestScratch.unique("canvas document tree")
        try FileManager.default.createDirectory(atPath: given + "/.git", withIntermediateDirectories: true)
        return (given, URL(filePath: given).resolvingSymlinksInPath().path)
    }

    @Test("a written document reads back and leaves no temporary file")
    func writeIsAtomicAndReadable() throws {
        let tree = try worktree()
        let path = tree.root + "/one.udcanvas"
        let document = CanvasDocument(frames: [CanvasFrame(name: "A", rect: CanvasRect(x: 0, y: 0, width: 10, height: 20))])

        let bytes = try CanvasDocumentFile.write(document, to: path)

        #expect(try Data(contentsOf: URL(filePath: path)) == bytes)
        #expect(CanvasDocumentCodec.decode(bytes) == .document(document))
        #expect(try CanvasDocumentFile.read(at: path) == .document(document))
        #expect(try FileManager.default.contentsOfDirectory(atPath: tree.root).filter { $0 != ".git" } == ["one.udcanvas"])
    }

    @Test("the next name skips the ones taken")
    func nextNameSkipsTaken() {
        #expect(CanvasDocumentFile.nextName(in: []) == "canvases/canvas.udcanvas")
        #expect(CanvasDocumentFile.nextName(in: ["canvases/canvas.udcanvas"]) == "canvases/canvas-2.udcanvas")
        #expect(CanvasDocumentFile.nextName(in: ["canvases/canvas.udcanvas", "canvases/canvas-2.udcanvas"]) == "canvases/canvas-3.udcanvas")
    }

    @Test("only the document extension is a document")
    func isDocument() {
        #expect(CanvasDocumentFile.isDocument(path: "a/b.udcanvas"))
        #expect(CanvasDocumentFile.isDocument(path: "a/b.UDCANVAS"))
        #expect(!CanvasDocumentFile.isDocument(path: "a/b.html"))
    }

    @Test("the backup path keeps the folder and carries the date")
    func backupPath() {
        let path = CanvasDocumentFile.backupPath(for: "/w/canvases/c.udcanvas", at: Date(timeIntervalSince1970: 0))
        #expect(path == "/w/canvases/c.backup-19700101T000000Z.udcanvas")
    }

    @Test("a missing document is created with one 1080 by 1350 frame")
    func resolveCreatingMakesAMissingDocument() throws {
        let tree = try worktree()
        let result = CanvasFile.resolveCreating(path: "canvases/new.udcanvas", worktree: tree.given)

        #expect(result == .file(absolute: tree.root + "/canvases/new.udcanvas", relative: "canvases/new.udcanvas"))
        guard case let .document(document) = try CanvasDocumentFile.read(at: tree.root + "/canvases/new.udcanvas") else {
            Issue.record("expected a document")
            return
        }
        let frame = try #require(document.frames.first)
        #expect(document.frames.count == 1)
        #expect(frame.name == "Slide 1")
        #expect(frame.fill == "#FFFFFF")
        #expect(frame.revision == 0)
        #expect(frame.rect == CanvasRect(x: 0, y: 0, width: 1080, height: 1350))
    }

    @Test("creating refuses a path outside the worktree and creates nothing")
    func resolveCreatingRefusesOutsideTheWorktree() throws {
        let tree = try worktree()
        let outside = (tree.root as NSString).deletingLastPathComponent + "/escaped-\(UUID().uuidString).udcanvas"
        let relative = CanvasFile.resolveCreating(path: "../escaped-\(UUID().uuidString)/x.udcanvas", worktree: tree.given)
        let absolute = CanvasFile.resolveCreating(path: outside, worktree: tree.given)

        guard case .refused = relative, case .refused = absolute else {
            Issue.record("expected both refused")
            return
        }
        #expect(!FileManager.default.fileExists(atPath: outside))
    }

    @Test("creating refuses a withheld path")
    func resolveCreatingRefusesWithheld() throws {
        let tree = try worktree()
        let result = CanvasFile.resolveCreating(path: ".git/hooks/x.udcanvas", worktree: tree.given)

        guard case .refused = result else {
            Issue.record("expected refused")
            return
        }
        #expect(!FileManager.default.fileExists(atPath: tree.root + "/.git/hooks"))
    }

    @Test("creating leaves other types refused")
    func resolveCreatingLeavesOtherTypesRefused() throws {
        let tree = try worktree()
        let result = CanvasFile.resolveCreating(path: "docs/missing.html", worktree: tree.given)

        guard case .refused = result else {
            Issue.record("expected refused")
            return
        }
        #expect(!FileManager.default.fileExists(atPath: tree.root + "/docs"))
    }

    @Test("creating keeps an existing document byte for byte")
    func resolveCreatingKeepsAnExistingDocument() throws {
        let tree = try worktree()
        let path = tree.root + "/keep.udcanvas"
        try "not even json".write(toFile: path, atomically: true, encoding: .utf8)
        let before = try Data(contentsOf: URL(filePath: path))

        let result = CanvasFile.resolveCreating(path: "keep.udcanvas", worktree: tree.given)

        #expect(result == .file(absolute: path, relative: "keep.udcanvas"))
        #expect(try Data(contentsOf: URL(filePath: path)) == before)
    }
}
