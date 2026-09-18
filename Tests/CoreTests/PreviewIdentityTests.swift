import Testing
import Foundation
@testable import Core

@Suite("A worktree's preview identity")
struct PreviewIdentityTests {
    private let worktree = "/Users/tester/unified-dev/.claude/worktrees/worktree-preview-apps"

    @Test("every name the preview goes by comes from the worktree, the branch and the label")
    func derivesEveryName() throws {
        let identity = try PreviewIdentity(
            worktree: worktree, branch: "feat/31-worktree-preview-apps", label: "Preview apps per worktree"
        )
        #expect(identity.slug == "worktree-preview-apps")
        #expect(identity.bundleIdentifier == "io.akira.unifieddev.dev.worktree-preview-apps")
        #expect(identity.appName == "UD #31")
        #expect(identity.windowTitlePrefix == "[DEV \u{00B7} Preview apps per worktree] ")
        #expect(identity.urlScheme == "unifieddevdev-worktree-preview-apps")
        #expect(identity.servicesMenuItem == "New UD #31 Workspace")
        #expect(identity.appPath == worktree + "/.build/preview/UD #31.app")
        #expect(identity.databasePath == worktree + "/.build/preview/data/unifieddev.sqlite")
        #expect(identity.workspacesRoot == worktree + "/.build/preview/workspaces")
        #expect(identity.scratchRoot == worktree + "/.build/preview/scratch")
    }

    @Test("nothing the preview writes lands outside its worktree")
    func everythingStaysInsideTheWorktree() throws {
        let identity = try PreviewIdentity(worktree: worktree, branch: nil, label: nil)
        for path in [identity.appPath, identity.databasePath, identity.workspacesRoot, identity.scratchRoot] {
            #expect(FolderPath.isInside(path, of: worktree))
        }
    }

    @Test("a preview never takes the name, the database or the socket of the real or the dev copy")
    func neverCollidesWithAFixedIdentity() throws {
        let identity = try PreviewIdentity(worktree: worktree, branch: nil, label: nil)
        let fixed = [Store.primaryBundleIdentifier, Store.devBundleIdentifier, "io.akira.unifieddev.subagents"]
        #expect(!fixed.contains(identity.bundleIdentifier))
        #expect(!PreviewIdentity.isPreview(bundleIdentifier: Store.primaryBundleIdentifier))
        #expect(!PreviewIdentity.isPreview(bundleIdentifier: Store.devBundleIdentifier))
        #expect(!PreviewIdentity.isPreview(bundleIdentifier: Store.devBundleIdentifier + "."))
        #expect(PreviewIdentity.isPreview(bundleIdentifier: identity.bundleIdentifier))
        #expect(identity.bridgeServerName != BridgeRegistration.ownerServerName(forBundleIdentifier: Store.primaryBundleIdentifier))
        #expect(identity.bridgeServerName != BridgeRegistration.ownerServerName(forBundleIdentifier: Store.devBundleIdentifier))
        #expect(identity.urlScheme != "unifieddev" && identity.urlScheme != "unifieddevdev")
    }

    @Test("two worktrees are two apps, with nothing shared between them")
    func twoWorktreesShareNothing() throws {
        let one = try PreviewIdentity(worktree: worktree, branch: "feat/31-a", label: nil)
        let other = try PreviewIdentity(worktree: "/Users/tester/unified-dev/.claude/worktrees/sending-slot", branch: "fix/6-b", label: nil)
        #expect(one.bundleIdentifier != other.bundleIdentifier)
        #expect(one.appName != other.appName)
        #expect(one.urlScheme != other.urlScheme)
        #expect(one.databasePath != other.databasePath)
        #expect(one.tmuxSocket != other.tmuxSocket)
        #expect(one.bridgeServerName != other.bridgeServerName)
    }

    @Test("the slug is folded into something a bundle id and a URL scheme both accept")
    func slugIsSafe() throws {
        let identity = try PreviewIdentity(worktree: "/tmp/wt/Fix The_Thing!!", branch: nil, label: nil)
        #expect(identity.slug == "fix-the-thing")
        #expect(PreviewIdentity.isPreview(bundleIdentifier: identity.bundleIdentifier))
        #expect(!PreviewIdentity.isPreview(bundleIdentifier: PreviewIdentity.bundlePrefix + "Fix_The"))
    }

    @Test("a worktree with no usable name, or given as a relative path, has no identity")
    func refusesWithoutASlug() {
        #expect(throws: PreviewIdentityError.self) { try PreviewIdentity(worktree: "/tmp/___", branch: nil, label: nil) }
        #expect(throws: PreviewIdentityError.self) { try PreviewIdentity(worktree: "relative/wt", branch: nil, label: nil) }
    }

    @Test("the issue number is read only from a branch that leads with one", arguments: [
        ("feat/31-worktree-preview-apps", 31 as Int?),
        ("fix/6-relayed-message-bubble", 6),
        ("42-plain", 42),
        ("akira/bold-volhard-e2a0d0", nil),
        ("feat/v2-thing", nil),
        ("feat/31abc", nil),
    ])
    func readsTheIssue(branch: String, issue: Int?) {
        #expect(PreviewIdentity.issue(fromBranch: branch) == issue)
    }

    @Test("with no issue the Dock name falls back to the slug")
    func dockNameWithoutAnIssue() throws {
        let identity = try PreviewIdentity(worktree: worktree, branch: "akira/bold-volhard", label: nil)
        #expect(identity.appName == "UD worktree-preview-apps")
    }

    @Test("the label falls back to the branch, then the slug, and never carries a line break")
    func labelFallsBack() throws {
        #expect(try PreviewIdentity(worktree: worktree, branch: "feat/31-x", label: "  ").label == "feat/31-x")
        #expect(try PreviewIdentity(worktree: worktree, branch: nil, label: nil).label == "worktree-preview-apps")
        #expect(try PreviewIdentity(worktree: worktree, branch: nil, label: "two\nlines\t here").label == "two lines here")
    }

    @Test("a long label is shortened so the title still shows the workspace")
    func longLabelIsShortened() throws {
        let label = String(repeating: "word ", count: 20)
        let identity = try PreviewIdentity(worktree: worktree, branch: nil, label: label)
        #expect(identity.label.count == PreviewIdentity.labelLimit)
        #expect(identity.label.hasSuffix("\u{2026}"))
    }

    @Test("the window title carries the mark only when the bundle declares one")
    func titleMark() {
        #expect(WindowTitleMark.decorate("Harbour", prefix: "") == "Harbour")
        #expect(WindowTitleMark.decorate("Harbour", prefix: "[DEV] ") == "[DEV] Harbour")
        #expect(WindowTitleMark.prefix(info: [:]).isEmpty)
        #expect(WindowTitleMark.prefix(info: [PreviewIdentity.titlePrefixKey: "[DEV \u{00B7} x] "]) == "[DEV \u{00B7} x] ")
    }
}
