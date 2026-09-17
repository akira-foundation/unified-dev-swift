import Foundation
import Testing
@testable import Core

@Suite("Home's scopes")
struct HomeScopeTests {
    private func workspace(
        _ name: String,
        repoID: RepoID = RepoID("repo"),
        state: WorkspaceState = .active,
        unread: Bool = false
    ) -> Workspace {
        Workspace(
            id: WorkspaceID(name),
            repoID: repoID,
            name: name,
            branch: "feature/\(name)",
            path: "/tmp/\(name)",
            baseBranch: "main",
            state: state,
            lastActivityAt: Date(timeIntervalSince1970: 1_000),
            unread: unread
        )
    }

    private func row(_ workspace: Workspace) -> HomeRow {
        HomeRow(workspace: workspace, repo: Repo(id: workspace.repoID, name: "repo", path: "/tmp"))
    }

    @Test("the two sets share exactly one chip, and it is the widest one")
    func theSetsShareOnlyAll() {
        let browsing = Set(HomeScope.offered(searching: false))
        let searching = Set(HomeScope.offered(searching: true))
        #expect(browsing.contains(.all))
        #expect(searching.contains(.all))
        #expect(browsing.contains(.archived))
        #expect(searching.contains(.archived))
        #expect(!browsing.contains(.transcripts))
        #expect(!searching.contains(.running))
    }

    @Test("the resting chip is called All while browsing and Everything in a search")
    func theRestingChipIsRenamed() {
        #expect(HomeScope.all.label(searching: false) == "All")
        #expect(HomeScope.all.label(searching: true) == "Everything")
        #expect(HomeScope.archived.label(searching: false) == "Archived")
        #expect(HomeScope.archived.label(searching: true) == "Archived")
    }

    @Test("a chip that is not on offer falls back to the resting one")
    func aScopeThatIsNotOfferedSettles() {
        #expect(HomeScope.settle(.running, searching: true) == .all)
        #expect(HomeScope.settle(.transcripts, searching: false) == .all)
        #expect(HomeScope.settle(.all, searching: true) == .all)
    }

    @Test("Home rests on Live, and a search rests on Everything")
    func theRestingScopeIsLive() {
        #expect(HomeScope.resting(searching: false) == .all)
        #expect(HomeScope.resting(searching: true) == .all)
        #expect(HomeFilter().scope == .all)
    }

    @Test("Live leads the browsing chips and All closes them")
    func liveLeadsTheStrip() {
        #expect(HomeScope.offered(searching: false) == [.all, .archived])
        #expect(HomeScope.offered(searching: true).first == .all)
    }

    @Test("Live widens to everything when a search starts")
    func liveWidensIntoASearch() {
        #expect(HomeScope.settle(.live, searching: true) == .all)
    }

    @Test("Archived survives a search starting and ending")
    func archivedSurvivesTheCrossing() {
        #expect(HomeScope.settle(.archived, searching: true) == .archived)
        #expect(HomeScope.settle(.archived, searching: false) == .archived)
    }

    @Test("each chip lets through what its name says")
    func eachScopeLetsThroughWhatItSays() {
        let live = row(workspace("live"))
        let unread = row(workspace("unread", unread: true))
        let running = row(workspace("running"))
        let archived = row(workspace("gone", state: .archived))
        let activity = HomeActivity(
            running: [running.id], waiting: [WorkspaceID("asking")]
        )

        #expect(HomeScope.all.includes(archived, activity: activity))
        #expect(HomeScope.live.includes(live, activity: activity))
        #expect(!HomeScope.live.includes(archived, activity: activity))
        #expect(HomeScope.archived.includes(archived, activity: activity))
        #expect(!HomeScope.archived.includes(live, activity: activity))
        #expect(HomeScope.running.includes(running, activity: activity))
        #expect(!HomeScope.running.includes(live, activity: activity))
        #expect(HomeScope.needsYou.includes(unread, activity: activity))
        #expect(!HomeScope.needsYou.includes(live, activity: activity))
        #expect(!HomeScope.transcripts.includes(live, activity: activity))
    }

    @Test("Needs you covers a question asked and a turn unread")
    func needsYouCoversBoth() {
        let asking = workspace("asking")
        let unread = workspace("unread", unread: true)
        let activity = HomeActivity(waiting: [asking.id])
        #expect(activity.needsYou(asking))
        #expect(activity.needsYou(unread))
        #expect(!activity.needsYou(workspace("quiet")))
    }

    @Test("an archived workspace never needs you, whatever its unread flag says")
    func archivedNeverNeedsYou() {
        let stale = workspace("gone", state: .archived, unread: true)
        #expect(!HomeActivity(waiting: [stale.id]).needsYou(stale))
    }

    @Test("every chip counts what clicking it would show, whichever chip is lit")
    func countsIgnoreTheSelectedChip() {
        let workspaces = [
            workspace("running"),
            workspace("unread", unread: true),
            workspace("quiet"),
        ]
        let archived = [workspace("gone", state: .archived)]
        let activity = HomeActivity(running: [WorkspaceID("running")])

        for scope in HomeScope.offered(searching: false) {
            let listing = HomeList.build(
                repos: [Repo(id: RepoID("repo"), name: "repo", path: "/tmp")],
                workspaces: workspaces,
                archived: archived,
                filter: HomeFilter(scope: scope),
                activity: activity
            )
            #expect(listing.counts.live == 3)
            #expect(listing.counts.archived == 1)
            #expect(listing.counts.running == 1)
            #expect(listing.counts.needsYou == 1)
            #expect(listing.counts.count(of: .all, searching: false) == 4)
        }
    }

    @Test("a chip at nought draws no number")
    func aNoughtDrawsNoNumber() {
        var counts = HomeScopeCounts()
        counts.live = 3
        counts.archived = 17
        #expect(counts.badge(of: .archived, searching: false) == 17)
        #expect(counts.badge(of: .all, searching: false) == 20)
        #expect(counts.badge(of: .live, searching: false) == nil)
        #expect(counts.badge(of: .needsYou, searching: false) == nil)
        #expect(counts.badge(of: .running, searching: false) == nil)
        #expect(HomeScopeCounts().badge(of: .all, searching: false) == nil)
        #expect(HomeScopeCounts().badge(of: .archived, searching: false) == nil)
    }

    @Test("the project filter is inside the counts")
    func theProjectFilterIsInsideTheCounts() {
        let listing = HomeList.build(
            repos: [
                Repo(id: RepoID("a"), name: "a", path: "/tmp/a"),
                Repo(id: RepoID("b"), name: "b", path: "/tmp/b"),
            ],
            workspaces: [
                workspace("one", repoID: RepoID("a")),
                workspace("two", repoID: RepoID("b")),
            ],
            archived: [],
            filter: HomeFilter(projects: [RepoID("a")])
        )
        #expect(listing.counts.live == 1)
        #expect(listing.shown == 1)
        #expect(listing.considered == 2)
    }
}
