import Foundation
import Testing
@testable import Core

@Suite("Deleting the archived workspaces Home shows")
struct HomeArchiveDeletionTests {
    private let kriol = RepoID("kriol")
    private let unified = RepoID("unified-dev")

    private func workspace(_ name: String, in repoID: RepoID, state: WorkspaceState = .archived) -> Workspace {
        Workspace(
            id: WorkspaceID(name),
            repoID: repoID,
            name: name,
            branch: "feature/\(name)",
            path: "/tmp/\(name)",
            baseBranch: "main",
            state: state,
            lastActivityAt: Date(timeIntervalSince1970: 1_700_000_000)
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
            workspace("achado-09", in: kriol),
            workspace("achado-10", in: kriol),
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

    @Test("with no project chosen it takes every archived workspace")
    func everyProject() {
        #expect(ids(deletion(HomeFilter(scope: .archived))) == ["achado-09", "achado-10", "camotes-sea"])
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
}
