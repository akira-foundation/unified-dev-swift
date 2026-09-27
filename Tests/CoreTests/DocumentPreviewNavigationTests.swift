import Foundation
import Testing
@testable import Core

@Suite("Document preview navigation", .tags(.security), .scratchDirectory)
struct DocumentPreviewNavigationTests {
    private func root() throws -> String {
        let root = TestScratch.unique("navigation")
        try FileManager.default.createDirectory(atPath: root + "/docs", withIntermediateDirectories: true)
        for file in ["docs/report.html", "docs/other.html"] {
            try "x".write(toFile: root + "/" + file, atomically: true, encoding: .utf8)
        }
        return URL(filePath: root).resolvingSymlinksInPath().path
    }

    private func decide(
        _ target: String, root: String, mainFrame: Bool = true, clicked: Bool = true
    ) throws -> DocumentPreviewNavigation {
        DocumentPreviewNavigation.decide(
            target: try #require(URL(string: target)), document: root + "/docs/report.html", root: root,
            isMainFrame: mainFrame, isLinkActivated: clicked
        )
    }

    @Test("the document itself loads, fragment and all")
    func sameDocument() throws {
        let root = try root()
        #expect(try decide("unified-dev-preview://worktree/docs/report.html", root: root, clicked: false) == .allow)
        #expect(try decide("unified-dev-preview://worktree/docs/report.html#costs", root: root) == .allow)
    }

    @Test("a click on another file opens it in the app, a script moving the page does not")
    func otherFile() throws {
        let root = try root()
        let other = "unified-dev-preview://worktree/docs/other.html"
        #expect(try decide(other, root: root) == .openFile(root + "/docs/other.html"))
        #expect(try decide(other, root: root, clicked: false) == .refuse)
        #expect(try decide(other, root: root, mainFrame: false, clicked: false) == .allow)
    }

    @Test("a click that climbs out of the root is refused in every frame")
    func climbingLink() throws {
        let root = try root()
        let outside = "unified-dev-preview://worktree/../elsewhere.html"
        #expect(try decide(outside, root: root) == .refuse)
        #expect(try decide(outside, root: root, mainFrame: false, clicked: false) == .refuse)
    }

    @Test("a web link opens outside the app only when clicked, and never loads in a frame")
    func webLinks() throws {
        let root = try root()
        let url = try #require(URL(string: "https://example.com/page"))
        #expect(try decide("https://example.com/page", root: root) == .openExternally(url))
        #expect(try decide("https://example.com/page", root: root, clicked: false) == .refuse)
        #expect(try decide("https://example.com/page", root: root, mainFrame: false, clicked: false) == .refuse)
        #expect(try decide("http://example.com/page", root: root, mainFrame: false, clicked: true) == .refuse)
    }

    @Test("mail opens outside the app only when clicked")
    func mail() throws {
        let root = try root()
        let url = try #require(URL(string: "mailto:someone@example.com"))
        #expect(try decide("mailto:someone@example.com", root: root) == .openExternally(url))
        #expect(try decide("mailto:someone@example.com", root: root, clicked: false) == .refuse)
    }

    @Test("other schemes are refused, and only a blank page or srcdoc frame is allowed")
    func otherSchemes() throws {
        let root = try root()
        #expect(try decide("file:///etc/passwd", root: root) == .refuse)
        #expect(try decide("javascript:alert(1)", root: root) == .refuse)
        #expect(try decide("x-apple-something://open", root: root) == .refuse)
        #expect(try decide("data:text/html,hi", root: root) == .refuse)
        #expect(try decide("data:text/html,hi", root: root, mainFrame: false, clicked: false) == .refuse)
        #expect(try decide("blob:unified-dev-preview://worktree/1", root: root, mainFrame: false, clicked: false) == .refuse)
        #expect(try decide("about:blank", root: root, clicked: false) == .allow)
        #expect(try decide("about:config", root: root) == .refuse)
        #expect(try decide("about:srcdoc", root: root, mainFrame: false, clicked: false) == .allow)
    }
}
