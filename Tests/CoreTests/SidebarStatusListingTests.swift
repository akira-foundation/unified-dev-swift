import Foundation
import Testing
@testable import Core

@Suite("Sidebar status listing")
struct SidebarStatusListingTests {
    private func workspace(_ id: String, touched: Date = .distantPast, unread: Bool = false) -> Workspace {
        Workspace(
            id: WorkspaceID(id),
            repoID: RepoID("r1"),
            name: id,
            branch: "unifieddev/\(id)",
            path: "/tmp/\(id)",
            baseBranch: "main",
            lastActivityAt: touched,
            unread: unread
        )
    }

    private func pending(_ id: String) -> PendingWorkspace {
        PendingWorkspace(id: WorkspaceID(id), repoID: RepoID("r1"), name: id)
    }

    @Test("an empty section is not drawn")
    func emptySectionsAreNotDrawn() {
        let listing = SidebarStatusListing.build(workspaces: [workspace("a")], status: { _ in .clean })

        #expect(listing.sections.map(\.group) == [.idle])
    }

    @Test("sections come in the order the groups are declared in")
    func sectionOrder() {
        let rows = [workspace("idle"), workspace("run"), workspace("ask"), workspace("unread")]
        let listing = SidebarStatusListing.build(workspaces: rows) { workspace in
            switch workspace.id.rawValue {
            case "run": .running
            case "ask": .awaitingPermission
            case "unread": .unread
            default: .clean
            }
        }

        #expect(listing.sections.map(\.group) == [.needsYou, .readyToRead, .working, .idle])
    }

    @Test("rows outside Idle keep the order they were handed in, however recently they were touched")
    func keepsHandedOrder() {
        let now = Date()
        let listing = SidebarStatusListing.build(
            workspaces: [
                workspace("a", touched: now.addingTimeInterval(-86_400)),
                workspace("b", touched: now),
                workspace("c", touched: now.addingTimeInterval(-3_600)),
            ],
            status: { _ in .unread }
        )

        #expect(listing.sections.first?.workspaces.map(\.id.rawValue) == ["a", "b", "c"])
    }

    @Test("Idle puts what was touched last on top, and keeps the handed order on a tie")
    func idleRanksByRecency() {
        let now = Date()
        let rows = [
            workspace("old", touched: now.addingTimeInterval(-3_600)),
            workspace("tieFirst", touched: now.addingTimeInterval(-86_400)),
            workspace("justRead", touched: now),
            workspace("tieSecond", touched: now.addingTimeInterval(-86_400)),
        ]
        let listing = SidebarStatusListing.build(workspaces: rows, status: { _ in .clean })

        #expect(listing.sections.first?.workspaces.map(\.id.rawValue) == ["justRead", "old", "tieFirst", "tieSecond"])
    }

    @Test("an unread workspace with a merged pull request is listed as ready to read")
    func unreadOutranksPullRequest() {
        let listing = SidebarStatusListing.build(
            workspaces: [workspace("merged", unread: true), workspace("read")],
            status: { _ in .merged }
        )

        #expect(listing.sections.map(\.group) == [.readyToRead, .idle])
        #expect(listing.sections.first?.workspaces.map(\.id.rawValue) == ["merged"])
    }

    @Test("a held workspace stays in Ready to read after its flag has cleared")
    func holdKeepsReadyToRead() {
        let listing = SidebarStatusListing.build(
            workspaces: [workspace("a"), workspace("b")],
            holding: WorkspaceID("a"),
            status: { _ in .clean }
        )

        #expect(listing.sections.map(\.group) == [.readyToRead, .idle])
        #expect(listing.sections.first?.workspaces.map(\.id.rawValue) == ["a"])
    }

    @Test("a hold does not pull a working row out of Working")
    func holdLeavesWorkingAlone() {
        let listing = SidebarStatusListing.build(
            workspaces: [workspace("a")], holding: WorkspaceID("a"), status: { _ in .running }
        )

        #expect(listing.sections.map(\.group) == [.working])
    }

    @Test("a workspace being cut is listed under Working, above Idle, and counted")
    func pendingJoinsWorking() {
        let listing = SidebarStatusListing.build(
            workspaces: [workspace("quiet")], pending: [pending("new")], status: { _ in .clean }
        )

        #expect(listing.sections.map(\.group) == [.working, .idle])
        #expect(listing.sections.first?.workspaces.isEmpty == true)
        #expect(listing.sections.first?.pending.map(\.id.rawValue) == ["new"])
        #expect(listing.sections.first?.count == 1)
    }

    @Test("pending rows follow the running ones in the same section")
    func pendingAfterRunning() {
        let listing = SidebarStatusListing.build(
            workspaces: [workspace("run")], pending: [pending("new")], status: { _ in .running }
        )

        #expect(listing.sections.count == 1)
        #expect(listing.sections.first?.count == 2)
        #expect(listing.arrangement == ["working:run", "working:new"])
    }

    @Test("the arrangement changes when a row changes section")
    func arrangementFollowsSections() {
        let rows = [workspace("a"), workspace("b")]
        let before = SidebarStatusListing.build(workspaces: rows, status: { _ in .clean })
        let moved = SidebarStatusListing.build(workspaces: rows) { $0.id.rawValue == "a" ? .running : .clean }

        #expect(before.arrangement == ["idle:a", "idle:b"])
        #expect(moved.arrangement == ["working:a", "idle:b"])
    }

    @Test("the arrangement also changes when Idle reorders, because the order is part of it")
    func arrangementFollowsIdleOrder() {
        let now = Date()
        let before = SidebarStatusListing.build(
            workspaces: [workspace("a", touched: now), workspace("b", touched: now.addingTimeInterval(-60))],
            status: { _ in .clean }
        )
        let after = SidebarStatusListing.build(
            workspaces: [workspace("a", touched: now.addingTimeInterval(-60)), workspace("b", touched: now)],
            status: { _ in .clean }
        )

        #expect(before.arrangement == ["idle:a", "idle:b"])
        #expect(after.arrangement == ["idle:b", "idle:a"])
    }

    @Test("a workspace still starting is listed under Working")
    func startingIsWorking() {
        let listing = SidebarStatusListing.build(workspaces: [workspace("fresh")]) { workspace in
            WorkspaceStatus.resolve(workspace: workspace, isRunning: false, pullRequest: nil, isStarting: true)
        }

        #expect(listing.sections.map(\.group) == [.working])
    }

    @Test("drafts come before every section, in the order they were handed in")
    func draftsLead() {
        let listing = SidebarStatusListing.build(
            workspaces: [workspace("run")],
            drafts: [RepoID("r2"), RepoID("r1")],
            status: { _ in .running }
        )

        #expect(listing.drafts == [RepoID("r2"), RepoID("r1")])
        #expect(listing.arrangement == ["draft:r2", "draft:r1", "working:run"])
    }

    @Test("a fold is kept while the section is still big enough to offer it")
    func foldIsKept() {
        let rows = (1...4).map { workspace("w\($0)") }
        let listing = SidebarStatusListing.build(workspaces: rows, status: { _ in .clean })

        #expect(listing.folding([.idle]) == [.idle])
    }

    @Test("a fold is let go once the section is too small to offer it, so it cannot come back on its own")
    func foldIsPrunedWhenTheSectionShrinks() {
        let rows = (1...3).map { workspace("w\($0)") }
        let listing = SidebarStatusListing.build(workspaces: rows, status: { _ in .clean })

        #expect(listing.folding([.idle]).isEmpty)
    }

    @Test("a fold is let go when its section is no longer listed at all")
    func foldIsPrunedWhenTheSectionGoes() {
        let listing = SidebarStatusListing.build(workspaces: [workspace("a")], status: { _ in .running })

        #expect(listing.folding([.idle]).isEmpty)
    }

    @Test("a section that never folds is never kept folded, however many rows it holds")
    func onlyFoldableGroupsSurvive() {
        let rows = (1...9).map { workspace("w\($0)") }
        let listing = SidebarStatusListing.build(workspaces: rows, status: { _ in .unread })

        #expect(listing.folding([.readyToRead, .idle]).isEmpty)
    }

    @Test("a draft on its own makes no section")
    func draftAlone() {
        let listing = SidebarStatusListing.build(workspaces: [], drafts: [RepoID("r1")], status: { _ in .clean })

        #expect(listing.sections.isEmpty)
        #expect(listing.drafts == [RepoID("r1")])
    }
}
