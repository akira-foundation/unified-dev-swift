import Foundation
import Testing
@testable import Core

@Suite("Workspace diff pages")
struct WorkspaceDiffPageTests {
    private let workspace = WorkspaceID("w1")

    @Test("pages end on a line break, never exceed the limit, and join back into the diff")
    func linePages() throws {
        let diff = (1...40).map { "line \($0)\n" }.joined()
        var cursor: WorkspaceDiffPage.Cursor?
        var joined = ""
        var count = 0
        repeat {
            let page = try WorkspaceDiffPage.make(diff: diff, path: nil, workspaceID: workspace, cursor: cursor, limit: 50)
            #expect(page.text.count <= 50)
            #expect(page.offset == joined.count)
            if !page.complete { #expect(page.text.hasSuffix("\n")) }
            joined += page.text
            cursor = page.nextCursor
            count += 1
        } while cursor != nil && count < 100
        #expect(joined == diff)
    }

    @Test("a line longer than a page is cut at the limit rather than lost")
    func longLine() throws {
        let diff = String(repeating: "y", count: 120)
        let first = try WorkspaceDiffPage.make(diff: diff, path: nil, workspaceID: workspace, cursor: nil, limit: 50)
        #expect(first.text.count == 50)
        let cursor = try #require(first.nextCursor)
        #expect(cursor.offset == 50)
    }

    @Test("a cursor is refused once the diff moves, for another path, and for another workspace")
    func staleCursors() throws {
        let diff = String(repeating: "z\n", count: 100)
        let page = try WorkspaceDiffPage.make(diff: diff, path: "a", workspaceID: workspace, cursor: nil, limit: 20)
        let cursor = try #require(page.nextCursor)

        #expect(throws: WorkspaceDiffPage.StaleCursor.self) {
            try WorkspaceDiffPage.make(diff: diff + "more\n", path: "a", workspaceID: workspace, cursor: cursor, limit: 20)
        }
        #expect(throws: WorkspaceDiffPage.StaleCursor.self) {
            try WorkspaceDiffPage.make(diff: diff, path: "b", workspaceID: workspace, cursor: cursor, limit: 20)
        }
        #expect(WorkspaceDiffPage.Cursor(cursor.rawValue, workspaceID: WorkspaceID("w2")) == nil)
        #expect(WorkspaceDiffPage.Cursor(cursor.rawValue, workspaceID: workspace) == cursor)
        for bad in ["", "w1", "w1::0", "w1:abc:-1", "w1:abc:x", "w1:abc:0:1"] {
            #expect(WorkspaceDiffPage.Cursor(bad, workspaceID: workspace) == nil)
        }
    }

    @Test("an empty diff is one complete, empty page")
    func empty() throws {
        let page = try WorkspaceDiffPage.make(diff: "", path: nil, workspaceID: workspace, cursor: nil)
        #expect(page == WorkspaceDiffPage.Page(text: "", offset: 0, complete: true, nextCursor: nil))
    }

    @Test("the fingerprint is stable, and moves with the diff and with the path")
    func fingerprint() {
        let one = WorkspaceDiffPage.fingerprint(diff: "+a\n", path: nil)
        #expect(one == WorkspaceDiffPage.fingerprint(diff: "+a\n", path: nil))
        #expect(one != WorkspaceDiffPage.fingerprint(diff: "+b\n", path: nil))
        #expect(one != WorkspaceDiffPage.fingerprint(diff: "+a\n", path: "a"))
    }
}
