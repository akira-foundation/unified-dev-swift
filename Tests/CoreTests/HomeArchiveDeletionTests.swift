import Foundation
import Testing
@testable import Core

@Suite("Deleting the archived workspaces Home shows")
struct HomeArchiveDeletionTests {
    private let kriol = RepoID("kriol")
    private let unified = RepoID("unified-dev")

    private func workspace(
        _ name: String, in repoID: RepoID, state: WorkspaceState = .archived, daysAgo: Double = 0
    ) -> Workspace {
        Workspace(
            id: WorkspaceID(name),
            repoID: repoID,
            name: name,
            branch: "feature/\(name)",
            path: "/tmp/\(name)",
            baseBranch: "main",
            state: state,
            lastActivityAt: Date().addingTimeInterval(-daysAgo * 86_400)
        )
    }

    private func footprint(_ workspace: Workspace) -> ArchivedWorkspaceFootprint {
        ArchivedWorkspaceFootprint(
            workspace: workspace,
            repoName: workspace.repoID.rawValue,
            sessionCount: 1,
            messageCount: 3,
            transcriptBytes: 1_000,
            otherBytes: 0,
            reviewCommentCount: 0,
            hasNote: false
        )
    }

    private var archived: [Workspace] {
        [
            workspace("achado-09", in: kriol, daysAgo: 40),
            workspace("achado-10", in: kriol, daysAgo: 2),
            workspace("camotes-sea", in: unified),
        ]
    }

    private func deletion(
        _ filter: HomeFilter,
        measured: [Workspace]? = nil
    ) -> ArchiveDeletion? {
        HomeList.build(
            repos: [Repo(id: kriol, name: "kriol", path: "/tmp/kriol"),
                    Repo(id: unified, name: "unified-dev", path: "/tmp/unified-dev")],
            workspaces: [workspace("live", in: kriol, state: .active)],
            archived: archived,
            filter: filter,
            footprints: ArchiveCleanup(footprints: (measured ?? archived).map(footprint))
        ).deletion
    }

    private func ids(_ deletion: ArchiveDeletion?) -> Set<String> {
        Set(deletion?.footprints.map(\.id.rawValue) ?? [])
    }

    @Test("with no project chosen it takes every archived workspace, across every date group")
    func everyProject() {
        let filter = HomeFilter(scope: .archived)
        let groups = HomeList.build(
            repos: [], workspaces: [], archived: archived, filter: filter,
            footprints: ArchiveCleanup(footprints: archived.map(footprint))
        ).groups
        #expect(groups.count > 1)
        #expect(ids(deletion(filter)) == ["achado-09", "achado-10", "camotes-sea"])
    }

    @Test("a live row never joins the deletion, even one carrying a footprint")
    func neverTakesALiveRow() {
        let live = workspace("live", in: kriol, state: .active)
        let gone = workspace("gone", in: kriol)
        let listing = HomeListing(
            groups: [HomeGroup(id: "today", title: "Today", rows: [
                HomeRow(workspace: live, footprint: footprint(live)),
                HomeRow(workspace: gone, footprint: footprint(gone)),
            ])],
            shown: 2, considered: 2, archived: 1, shownArchived: 1
        )
        #expect(ids(listing.deletion) == ["gone"])
    }

    @Test("with one project chosen it takes only that project's")
    func oneProject() {
        let chosen = deletion(HomeFilter(projects: [kriol], scope: .archived))
        #expect(ids(chosen) == ["achado-09", "achado-10"])
    }

    @Test("a search narrows it to the rows that match")
    func narrowedBySearch() {
        #expect(ids(deletion(HomeFilter(query: "achado-10", scope: .archived))) == ["achado-10"])
    }

    @Test("outside the Archived scope nothing is offered, not even the archived rows All shows")
    func onlyUnderArchived() {
        #expect(deletion(HomeFilter(scope: .all)) == nil)
    }

    @Test("an empty list offers nothing")
    func emptyList() {
        #expect(deletion(HomeFilter(query: "nothing-matches-this", scope: .archived)) == nil)
    }

    @Test("while a shown row is not measured yet nothing is offered, so the count never undercounts")
    func waitsForEveryFootprint() {
        let partly = deletion(HomeFilter(scope: .archived), measured: Array(archived.prefix(2)))
        #expect(partly == nil)
    }

    @Test("the action names how many it deletes")
    func actionTitle() {
        #expect(deletion(HomeFilter(scope: .archived))?.actionTitle == "Delete 3")
        #expect(deletion(HomeFilter(projects: [unified], scope: .archived))?.actionTitle == "Delete 1")
    }

    @Test("the help says what the action takes, in the singular for one")
    func actionHelp() {
        #expect(deletion(HomeFilter(scope: .archived))?.actionHelp == "Delete the 3 archived workspaces shown here")
        #expect(
            deletion(HomeFilter(projects: [unified], scope: .archived))?.actionHelp
                == "Delete the archived workspace shown here"
        )
    }
}
