import Foundation
import Testing
@testable import Core

@Suite("Canvas image path", .tags(.security), .scratchDirectory)
struct CanvasImagePathTests {
    private func worktree() throws -> String {
        let given = TestScratch.unique("canvas image tree")
        try FileManager.default.createDirectory(atPath: given + "/design/assets", withIntermediateDirectories: true)
        try "x".write(toFile: given + "/design/assets/a.png", atomically: true, encoding: .utf8)
        return URL(filePath: given).resolvingSymlinksInPath().path
    }

    @Test("an image inside the worktree resolves beside the document")
    func imageInsideWorktreeResolves() throws {
        let root = try worktree()
        let result = CanvasImagePath.resolve("assets/a.png", beside: root + "/design/ui.canvas", worktree: root)
        #expect(result == root + "/design/assets/a.png")
    }

    @Test("a path that leaves the worktree is refused")
    func imageEscapingIsRefused() throws {
        let root = try worktree()
        let outside = (root as NSString).deletingLastPathComponent + "/outside.png"
        try "secret".write(toFile: outside, atomically: true, encoding: .utf8)
        try FileManager.default.createSymbolicLink(atPath: root + "/design/link.png", withDestinationPath: outside)
        let document = root + "/design/ui.canvas"
        #expect(CanvasImagePath.resolve("../../x.png", beside: document, worktree: root) == nil)
        #expect(CanvasImagePath.resolve(outside, beside: document, worktree: root) == nil)
        #expect(CanvasImagePath.resolve("link.png", beside: document, worktree: root) == nil)
    }
}
