import Foundation
import Testing
@testable import Core

@Suite("BridgeOwnerPlacement")
struct BridgeOwnerPlacementTests {
    private let repo = Repo(name: "unifieddev", path: "/Users/someone/code/unifieddev")

    private func workspace(_ name: String, at path: String, archived: Bool = false) -> Workspace {
        var workspace = Workspace(
            repoID: repo.id, name: name, branch: "unifieddev/\(name)", path: path, baseBranch: "main"
        )
        if archived { workspace.archive() }
        return workspace
    }

    private var live: [Workspace] {
        [
            workspace("bothnian-sea", at: "/Users/someone/unifieddev/workspaces/bothnian-sea"),
            workspace("baltic", at: "/Users/someone/unifieddev/workspaces/baltic/"),
        ]
    }

    @Test("a directory inside a live workspace is refused, and the sentence names the workspace", arguments: [
        "/Users/someone/unifieddev/workspaces/bothnian-sea/Sources/Core",
        "/Users/someone/unifieddev/workspaces/bothnian-sea",
        "/Users/someone/unifieddev/workspaces/bothnian-sea/",
        "/Users/someone/unifieddev/workspaces/bothnian-sea/./Tests",
    ])
    func insideIsRefused(_ directory: String) throws {
        let refusal = try #require(BridgeOwnerPlacement.refusal(workingDirectory: directory, workspaces: live))
        #expect(refusal.contains("'bothnian-sea'"))
        #expect(refusal.contains("/Users/someone/unifieddev/workspaces/bothnian-sea"))
        #expect(refusal.contains("outside Unified Dev's workspaces"))
    }

    @Test("a trailing slash on the workspace's own path makes no difference")
    func trailingSlashOnTheRow() throws {
        let refusal = BridgeOwnerPlacement.refusal(
            workingDirectory: "/Users/someone/unifieddev/workspaces/baltic", workspaces: live
        )
        #expect(try #require(refusal).contains("'baltic'"))
        let nested = BridgeOwnerPlacement.refusal(
            workingDirectory: "/Users/someone/unifieddev/workspaces/baltic/src", workspaces: live
        )
        #expect(nested != nil)
    }

    @Test("a directory in no workspace is let through", arguments: [
        "/Users/someone/unifieddev/workspaces/bothnian-sea-2",
        "/Users/someone/unifieddev/workspaces/balticsea/src",
        "/Users/someone/unifieddev/workspaces",
        "/Users/someone",
        "/Users/someone/Library/Application Support/Unified Dev/Ask",
        "/",
    ])
    func outsideIsLetThrough(_ directory: String) {
        #expect(BridgeOwnerPlacement.refusal(workingDirectory: directory, workspaces: live) == nil)
    }

    @Test("no directory at all is let through")
    func unreadableDirectory() {
        #expect(BridgeOwnerPlacement.refusal(workingDirectory: nil, workspaces: live) == nil)
        #expect(BridgeOwnerPlacement.refusal(workingDirectory: "", workspaces: live) == nil)
    }

    @Test("an archived workspace never refuses")
    func archivedIsIgnored() {
        let archived = [workspace("old", at: "/Users/someone/unifieddev/workspaces/old", archived: true)]
        let refusal = BridgeOwnerPlacement.refusal(
            workingDirectory: "/Users/someone/unifieddev/workspaces/old/src", workspaces: archived
        )
        #expect(refusal == nil)
    }

    @Test("a workspace with no path never refuses")
    func emptyPathIsIgnored() {
        let pathless = [workspace("nowhere", at: "")]
        for directory in ["/", "/Users/someone", "/tmp/anything"] {
            #expect(BridgeOwnerPlacement.refusal(workingDirectory: directory, workspaces: pathless) == nil)
        }
    }

    @Test("with no workspaces at all, nothing is refused")
    func noWorkspaces() {
        #expect(BridgeOwnerPlacement.refusal(workingDirectory: "/Users/someone", workspaces: []) == nil)
    }

    @Test("Ask's own directory beside the database is outside the workspaces root, so Ask keeps the owner's tools")
    func askDirectoryIsLetThrough() {
        let database = "/Users/someone/Library/Application Support/Unified Dev/unifieddev.sqlite"
        let ask = AskConversation.directory(besideDatabaseAt: database)
        let root = WorkspaceManager.workspacesRoot.path
        let workspaces = [
            workspace("north-sea", at: (root as NSString).appendingPathComponent("unifieddev/north-sea")),
        ]

        #expect(ask == "/Users/someone/Library/Application Support/Unified Dev/Ask")
        #expect(!ask.hasPrefix(root + "/"))
        #expect(BridgeOwnerPlacement.refusal(workingDirectory: ask, workspaces: workspaces) == nil)
    }

    @Test("an Ask tab the owner pointed inside a live workspace is refused, because its shim runs there")
    func askTabInsideAWorkspaceIsRefused() {
        let refusal = BridgeOwnerPlacement.refusal(
            workingDirectory: "/Users/someone/unifieddev/workspaces/baltic/docs", workspaces: live
        )
        #expect(refusal != nil)
    }
}
