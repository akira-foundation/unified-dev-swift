import Foundation
import Testing
@testable import Core

@Suite("Document preview containment", .tags(.security), .scratchDirectory)
struct DocumentPreviewContainmentTests {
    private struct Tree {
        let given: String
        let root: String
    }

    private func tree() throws -> Tree {
        let given = TestScratch.unique("preview work tree")
        try FileManager.default.createDirectory(atPath: given + "/docs/assets", withIntermediateDirectories: true)
        for file in ["docs/report.html", "docs/assets/app.css"] {
            try "x".write(toFile: given + "/" + file, atomically: true, encoding: .utf8)
        }
        return Tree(given: given, root: URL(filePath: given).resolvingSymlinksInPath().path)
    }

    private func address(_ text: String) throws -> URL {
        try #require(URL(string: text))
    }

    private func secret() throws -> String {
        let path = TestScratch.unique("secret")
        try "secret".write(toFile: path, atomically: true, encoding: .utf8)
        return path
    }

    @Test("a file's address resolves back to the same file, in a root with spaces")
    func roundTrip() throws {
        let tree = try tree()
        let odd = tree.root + "/docs/draft #2 at 100%.html"
        try "x".write(toFile: odd, atomically: true, encoding: .utf8)

        let target = try #require(DocumentPreview.address(forFile: odd, root: tree.given))

        #expect(target.scheme == DocumentPreview.scheme)
        #expect(!target.absoluteString.contains(" "))
        #expect(DocumentPreview.file(for: target, root: tree.given)?.path == odd)
    }

    @Test("a relative asset resolves from the document's own folder")
    func relativeAsset() throws {
        let tree = try tree()
        let document = try #require(DocumentPreview.address(forFile: tree.root + "/docs/report.html", root: tree.root))
        let stylesheet = try #require(URL(string: "assets/app.css", relativeTo: document)?.absoluteURL)
        #expect(DocumentPreview.file(for: stylesheet, root: tree.root)?.path == tree.root + "/docs/assets/app.css")
    }

    @Test("a climb out of the root is refused however it is spelled", arguments: [
        "unified-dev-preview://worktree/../SECRET",
        "unified-dev-preview://worktree/docs/../../SECRET",
        "unified-dev-preview://worktree/docs/%2E%2E/%2E%2E/SECRET",
        "unified-dev-preview://worktree/%2e%2e/SECRET",
        "unified-dev-preview://worktree/docs%2F..%2F..%2FSECRET",
    ])
    func climbing(_ template: String) throws {
        let tree = try tree()
        let name = (try secret() as NSString).lastPathComponent
        let target = try address(template.replacingOccurrences(of: "SECRET", with: name))
        #expect(DocumentPreview.file(for: target, root: tree.given) == nil)
    }

    @Test("a percent sign is decoded once and never twice")
    func doubleEncodingStaysInside() throws {
        let tree = try tree()
        let literal = tree.root + "/docs/%2E%2E"
        try FileManager.default.createDirectory(atPath: literal, withIntermediateDirectories: true)
        try "inner".write(toFile: literal + "/inner.html", atomically: true, encoding: .utf8)
        let target = try address("unified-dev-preview://worktree/docs/%252E%252E/inner.html")
        #expect(DocumentPreview.file(for: target, root: tree.root)?.path == literal + "/inner.html")
    }

    @Test("a NUL byte in the path is refused")
    func nulByte() throws {
        let tree = try tree()
        let target = try address("unified-dev-preview://worktree/docs/report.html%00.png")
        #expect(DocumentPreview.file(for: target, root: tree.root) == nil)
    }

    @Test("a symlinked file pointing out of the root is refused")
    func symlinkedFile() throws {
        let tree = try tree()
        try FileManager.default.createSymbolicLink(atPath: tree.root + "/docs/link.html", withDestinationPath: try secret())
        let target = try address("unified-dev-preview://worktree/docs/link.html")
        #expect(DocumentPreview.file(for: target, root: tree.root) == nil)
    }

    @Test("a symlinked folder pointing out of the root is refused, and its index with it")
    func symlinkedFolder() throws {
        let tree = try tree()
        let outside = TestScratch.unique("outside")
        try FileManager.default.createDirectory(atPath: outside, withIntermediateDirectories: true)
        try "secret".write(toFile: outside + "/index.html", atomically: true, encoding: .utf8)
        try FileManager.default.createSymbolicLink(atPath: tree.root + "/docs/escape", withDestinationPath: outside)
        let page = try address("unified-dev-preview://worktree/docs/escape/index.html")
        let folder = try address("unified-dev-preview://worktree/docs/escape/")
        #expect(DocumentPreview.file(for: page, root: tree.root) == nil)
        #expect(DocumentPreview.file(for: folder, root: tree.root) == nil)
    }

    @Test("a folder whose index is a symlink out of the root is refused")
    func symlinkedIndex() throws {
        let tree = try tree()
        try FileManager.default.createSymbolicLink(atPath: tree.root + "/docs/index.html", withDestinationPath: try secret())
        let folder = try address("unified-dev-preview://worktree/docs/")
        #expect(DocumentPreview.file(for: folder, root: tree.root) == nil)
    }

    @Test("a symlink that stays inside the root is followed")
    func symlinkInside() throws {
        let tree = try tree()
        try FileManager.default.createSymbolicLink(
            atPath: tree.root + "/latest.html", withDestinationPath: tree.root + "/docs/report.html"
        )
        let target = try address("unified-dev-preview://worktree/latest.html")
        #expect(DocumentPreview.file(for: target, root: tree.root)?.path == tree.root + "/docs/report.html")
    }

    @Test("a sibling folder sharing the root's name as a prefix is outside it")
    func siblingPrefix() throws {
        let tree = try tree()
        let sibling = tree.root + "-evil"
        try FileManager.default.createDirectory(atPath: sibling, withIntermediateDirectories: true)
        try "secret".write(toFile: sibling + "/report.html", atomically: true, encoding: .utf8)
        let name = (sibling as NSString).lastPathComponent
        let encoded = try #require(name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed))
        let target = try address("unified-dev-preview://worktree/../\(encoded)/report.html")
        #expect(DocumentPreview.file(for: target, root: tree.root) == nil)
        #expect(DocumentPreview.address(forFile: sibling + "/report.html", root: tree.root) == nil)
    }

    @Test("another scheme, another host or an empty root is refused")
    func wrongAddress() throws {
        let tree = try tree()
        let plainFile = URL(filePath: tree.root + "/docs/report.html")
        let otherHost = try address("unified-dev-preview://elsewhere/docs/report.html")
        let valid = try address("unified-dev-preview://worktree/docs/report.html")
        #expect(DocumentPreview.file(for: plainFile, root: tree.root) == nil)
        #expect(DocumentPreview.file(for: otherHost, root: tree.root) == nil)
        #expect(DocumentPreview.file(for: valid, root: "") == nil)
        #expect(DocumentPreview.file(for: valid, root: tree.root)?.path == tree.root + "/docs/report.html")
    }

    @Test("a folder answers with its index page")
    func folderIndex() throws {
        let tree = try tree()
        try "x".write(toFile: tree.root + "/docs/index.html", atomically: true, encoding: .utf8)
        let folder = try address("unified-dev-preview://worktree/docs/")
        #expect(DocumentPreview.file(for: folder, root: tree.root)?.path == tree.root + "/docs/index.html")
    }

    @Test("a file outside any worktree reads only its own folder")
    func rootOutsideWorktree() throws {
        let tree = try tree()
        #expect(DocumentPreview.root(forFile: tree.root + "/docs/report.html", worktree: tree.root) == tree.root)
        #expect(DocumentPreview.root(forFile: "/tmp/elsewhere/report.html", worktree: tree.root) == "/tmp/elsewhere")
        #expect(DocumentPreview.root(forFile: "/tmp/elsewhere/report.html", worktree: nil) == "/tmp/elsewhere")
    }

    @Test("a clicked file inside the worktree opens by its relative path, through a symlinked root")
    func worktreePath() throws {
        let tree = try tree()
        let alias = TestScratch.unique("alias")
        try FileManager.default.createSymbolicLink(atPath: alias, withDestinationPath: tree.root)
        #expect(DocumentPreview.worktreePath(of: tree.root + "/docs/report.html", worktree: alias) == "docs/report.html")
        #expect(DocumentPreview.worktreePath(of: "/elsewhere/report.html", worktree: alias) == "/elsewhere/report.html")
        #expect(DocumentPreview.worktreePath(of: tree.root + "-evil/report.html", worktree: tree.root)
            == tree.root + "-evil/report.html")
    }
}
