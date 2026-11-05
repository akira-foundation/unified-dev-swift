import Foundation
import Testing
@testable import Core

@Suite("CanvasImageImport")
struct CanvasImageImportTests {
    @Test func importAvoidsNameClash() {
        let first = CanvasImageImport.destination(for: "/tmp/photo.png", beside: "/w/deck.udcanvas", existing: [])
        let second = CanvasImageImport.destination(for: "/tmp/photo.png", beside: "/w/deck.udcanvas", existing: [first])
        let third = CanvasImageImport.destination(for: "/tmp/photo.png", beside: "/w/deck.udcanvas", existing: [first, second])
        #expect(first == "deck.assets/photo.png")
        #expect(second == "deck.assets/photo 2.png")
        #expect(third == "deck.assets/photo 3.png")
    }

    @Test func theAssetsFolderIsNamedAfterTheDocument() {
        let path = CanvasImageImport.destination(for: "/a/b/x.jpg", beside: "/w/sub/My Deck.udcanvas", existing: [])
        #expect(path == "My Deck.assets/x.jpg")
    }

    @Test func aSourceWithoutAnExtensionKeepsNone() {
        let path = CanvasImageImport.destination(for: "/a/raw", beside: "/w/deck.udcanvas", existing: ["deck.assets/raw"])
        #expect(path == "deck.assets/raw 2")
    }

    @Test func anAssetsFolderThatIsALinkIsRefusedAndNothingGoesThroughIt() throws {
        let root = FileManager.default.temporaryDirectory.appending(path: "canvas-import-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        let outside = root.appending(path: "outside")
        let worktree = root.appending(path: "worktree")
        try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: worktree, withIntermediateDirectories: true)
        let source = root.appending(path: "photo.png")
        try Data("one".utf8).write(to: source)
        try FileManager.default.createSymbolicLink(at: worktree.appending(path: "deck.assets"), withDestinationURL: outside)

        #expect(throws: CanvasImageImport.FolderIsLink(name: "deck.assets")) {
            try CanvasImageImport.copy(source.path, beside: worktree.appending(path: "deck.udcanvas").path)
        }
        #expect(try FileManager.default.contentsOfDirectory(atPath: outside.path).isEmpty)
    }

    @Test func copyingWritesBesideTheDocumentAndNeverOverwrites() throws {
        let root = FileManager.default.temporaryDirectory.appending(path: "canvas-import-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let source = root.appending(path: "photo.png")
        try Data("one".utf8).write(to: source)
        let document = root.appending(path: "deck.udcanvas").path

        let first = try CanvasImageImport.copy(source.path, beside: document)
        let second = try CanvasImageImport.copy(source.path, beside: document)

        #expect(first == "deck.assets/photo.png")
        #expect(second == "deck.assets/photo 2.png")
        #expect(try Data(contentsOf: root.appending(path: second)) == Data("one".utf8))
    }

    @Test func fittedSizeNeverUpscalesAndKeepsTheAspect() {
        let frame = CanvasSize(width: 1000, height: 1000)
        let large = CanvasImageImport.fittedSize(of: CanvasSize(width: 4000, height: 2000), in: frame)
        let small = CanvasImageImport.fittedSize(of: CanvasSize(width: 200, height: 100), in: frame)
        #expect(large == CanvasSize(width: 800, height: 400))
        #expect(small == CanvasSize(width: 200, height: 100))
    }

    @Test func fittedSizeFallsBackForAnUnreadableImage() {
        let size = CanvasImageImport.fittedSize(of: CanvasSize(width: 0, height: 0), in: CanvasSize(width: 1000, height: 1000))
        #expect(size == CanvasSize(width: 400, height: 400))
    }
}
