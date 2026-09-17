import Foundation
import Testing
@testable import Core

@Suite("Local page")
struct LocalPageTests {
    private func makeRoot() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("local-page-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func write(_ name: String, in root: URL) throws -> URL {
        let file = root.appendingPathComponent(name)
        try FileManager.default.createDirectory(
            at: file.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        try Data("<html></html>".utf8).write(to: file)
        return file
    }

    @Test("HTML is a page, in either spelling and in either case")
    func acceptsHTML() {
        #expect(LocalPage.isPage(path: "index.html"))
        #expect(LocalPage.isPage(path: "docs/report.htm"))
        #expect(LocalPage.isPage(path: "INDEX.HTML"))
    }

    @Test("An SVG is a page, because nothing else in the window draws it")
    func acceptsSVG() {
        #expect(LocalPage.isPage(path: "public/logo.svg"))
    }

    @Test("What another pane already draws is not offered")
    func refusesWhatIsDrawnElsewhere() {
        #expect(!LocalPage.isPage(path: "README.md"))
        #expect(!LocalPage.isPage(path: "docs/spec.pdf"))
        #expect(!LocalPage.isPage(path: "shot.png"))
        #expect(!LocalPage.isPage(path: "Sources/App.swift"))
        #expect(!LocalPage.isPage(path: "Makefile"))
        #expect(!LocalPage.isPage(path: ""))
    }

    @Test("A page on disk is offered")
    func offersAPageOnDisk() throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let file = try write("index.html", in: root)

        #expect(LocalPage.canOpen(file: file.path))
        let address = try #require(LocalPage.address(forFile: file.path))
        #expect(URL(string: address)?.standardizedFileURL.path == file.standardizedFileURL.path)
    }

    @Test("A deleted file is not offered")
    func refusesAFileThatIsGone() throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let gone = root.appendingPathComponent("removed.html").path

        #expect(!LocalPage.canOpen(file: gone))
        #expect(LocalPage.address(forFile: gone) == nil)
    }

    @Test("A directory called index.html is not a page")
    func refusesADirectory() throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let directory = root.appendingPathComponent("index.html", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        #expect(!LocalPage.canOpen(file: directory.path))
    }

    @Test("The address is built rather than spelled out")
    func encodesTheAwkwardCharacters() throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let file = try write("draft #2/index.html", in: root)

        let address = try #require(LocalPage.address(forFile: file.path))
        #expect(address.hasPrefix("file://"))
        #expect(!address.contains(" "))
        #expect(!address.contains("#"))
        #expect(URL(string: address)?.standardizedFileURL.path == file.standardizedFileURL.path)
    }

    @Test("A page inside the worktree loads")
    func loadsInsideTheRoot() throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let file = try write("docs/report.html", in: root)

        let resolved = LocalPage.fileURL(from: file.absoluteString, root: root.path)
        #expect(resolved?.standardizedFileURL.path == file.standardizedFileURL.path)
    }

    @Test("A file outside the worktree is refused")
    func refusesOutsideTheRoot() throws {
        let root = try makeRoot()
        let neighbour = try makeRoot()
        defer {
            try? FileManager.default.removeItem(at: root)
            try? FileManager.default.removeItem(at: neighbour)
        }
        let outside = try write("index.html", in: neighbour)

        #expect(LocalPage.fileURL(from: outside.absoluteString, root: root.path) == nil)
    }

    @Test("A worktree does not claim its neighbour by name")
    func refusesASiblingWithTheSamePrefix() throws {
        let parent = try makeRoot()
        defer { try? FileManager.default.removeItem(at: parent) }
        let root = parent.appendingPathComponent("unifieddev", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let sibling = try write("unifieddev-old/index.html", in: parent)

        #expect(LocalPage.fileURL(from: sibling.absoluteString, root: root.path) == nil)
    }

    @Test("A path that climbs out of the worktree is refused")
    func refusesAClimbingPath() throws {
        let parent = try makeRoot()
        defer { try? FileManager.default.removeItem(at: parent) }
        let root = parent.appendingPathComponent("worktree", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        _ = try write("secret.html", in: parent)

        let climbing = "file://" + root.path + "/../secret.html"
        #expect(LocalPage.fileURL(from: climbing, root: root.path) == nil)
    }

    @Test("An http address is not this function's business")
    func ignoresAServerAddress() throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        #expect(LocalPage.fileURL(from: "http://localhost:3000/", root: root.path) == nil)
        #expect(LocalPage.fileURL(from: "https://akira-io.com", root: root.path) == nil)
        #expect(LocalPage.fileURL(from: "", root: root.path) == nil)
    }

    @Test("No worktree means no local page")
    func refusesWithoutARoot() throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let file = try write("index.html", in: root)

        #expect(LocalPage.fileURL(from: file.absoluteString, root: "") == nil)
    }

    @Test("The address rule still refuses a file URL")
    func leavesTheAddressRuleAlone() throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let file = try write("index.html", in: root)

        #expect(!BrowserAddress.shows(file))
        #expect(BrowserAddress.external(from: file.absoluteString) == nil)
    }
}
