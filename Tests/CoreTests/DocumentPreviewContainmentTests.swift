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

    @Test("the repository's own plumbing is never served, however it is reached")
    func withheldNames() throws {
        let tree = try tree()
        for folder in [".git", ".claude", "docs/.git"] {
            try FileManager.default.createDirectory(
                atPath: tree.root + "/" + folder, withIntermediateDirectories: true
            )
            try "secret".write(toFile: tree.root + "/" + folder + "/config", atomically: true, encoding: .utf8)
        }
        try "TOKEN=1".write(toFile: tree.root + "/.env", atomically: true, encoding: .utf8)
        try "TOKEN=1".write(toFile: tree.root + "/.env.local", atomically: true, encoding: .utf8)
        try FileManager.default.createSymbolicLink(
            atPath: tree.root + "/docs/sneak.html", withDestinationPath: tree.root + "/.git/config"
        )
        for spelling in [
            "unified-dev-preview://worktree/.git/config",
            "unified-dev-preview://worktree/.claude/config",
            "unified-dev-preview://worktree/docs/.git/config",
            "unified-dev-preview://worktree/.env",
            "unified-dev-preview://worktree/.env.local",
            "unified-dev-preview://worktree/docs/sneak.html",
        ] {
            #expect(DocumentPreview.file(for: try address(spelling), root: tree.root) == nil)
        }
        #expect(DocumentPreview.file(for: try address("unified-dev-preview://worktree/docs/report.html"),
                                     root: tree.root)?.path == tree.root + "/docs/report.html")
    }

    @Test("a folder whose index sits under withheld plumbing is refused")
    func withheldIndex() throws {
        let tree = try tree()
        try FileManager.default.createDirectory(atPath: tree.root + "/.git", withIntermediateDirectories: true)
        try "x".write(toFile: tree.root + "/.git/index.html", atomically: true, encoding: .utf8)
        #expect(DocumentPreview.file(for: try address("unified-dev-preview://worktree/.git/"), root: tree.root) == nil)
    }

    @Test("a document that is a symlink out of the worktree is rooted at what it points at")
    func symlinkedDocumentRoot() throws {
        let tree = try tree()
        let outside = TestScratch.unique("outside")
        try FileManager.default.createDirectory(atPath: outside + "/assets", withIntermediateDirectories: true)
        try "x".write(toFile: outside + "/report.html", atomically: true, encoding: .utf8)
        try "x".write(toFile: outside + "/assets/app.css", atomically: true, encoding: .utf8)
        let link = tree.root + "/docs/latest.html"
        try FileManager.default.createSymbolicLink(atPath: link, withDestinationPath: outside + "/report.html")

        let root = DocumentPreview.root(forFile: link, worktree: tree.root)
        let target = try #require(DocumentPreview.address(forFile: link, root: root))

        #expect(root == URL(filePath: outside).resolvingSymlinksInPath().path)
        #expect(DocumentPreview.file(for: target, root: root) != nil)
    }

    @Test("a flat root with no folder under it still resolves and still contains")
    func flatRoot() throws {
        let flat = TestScratch.unique("flat")
        try FileManager.default.createDirectory(atPath: flat, withIntermediateDirectories: true)
        let root = URL(filePath: flat).resolvingSymlinksInPath().path
        try "x".write(toFile: root + "/report.html", atomically: true, encoding: .utf8)
        let target = try #require(DocumentPreview.address(forFile: root + "/report.html", root: root))
        #expect(DocumentPreview.file(for: target, root: root)?.path == root + "/report.html")
        #expect(DocumentPreview.file(for: try address("unified-dev-preview://worktree/../escape"), root: root) == nil)
    }

    @Test("an empty worktree name reads only the file's own folder")
    func emptyWorktree() throws {
        let tree = try tree()
        #expect(DocumentPreview.root(forFile: tree.root + "/docs/report.html", worktree: "") == tree.root + "/docs")
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
