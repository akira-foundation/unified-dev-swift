import Testing
@testable import Core

@Suite("Picking a project to start from")
struct StartProjectPickTests {
    private func repo(_ id: String, hidden: Bool = false) -> Repo {
        Repo(id: RepoID(id), name: id, path: "/tmp/\(id)", hidden: hidden)
    }

    private func workspace(_ id: String, in repoID: String) -> Workspace {
        Workspace(
            id: WorkspaceID(id),
            repoID: RepoID(repoID),
            name: id,
            branch: "unifieddev/\(id)",
            path: "/tmp/\(id)",
            baseBranch: "main"
        )
    }

    @Test("a hidden project is not offered unless hidden projects are showing")
    func hiddenIsNotOffered() {
        let repos = [repo("harbour"), repo("almanac", hidden: true)]

        #expect(StartProjectPick.offered(repos, showingHidden: false).map(\.name) == ["harbour"])
        #expect(StartProjectPick.offered(repos, showingHidden: true).map(\.name) == ["harbour", "almanac"])
    }

    @Test("a recent folder that is already a project is matched to it, however the path is written")
    func matchesARecentFolderToItsProject() {
        let repos = [repo("harbour"), repo("beacon")]

        #expect(StartProjectPick.project(at: "/tmp/harbour", repos: repos)?.name == "harbour")
        #expect(StartProjectPick.project(at: "/tmp/harbour/", repos: repos)?.name == "harbour")
    }

    @Test("a recent folder that was never added as a project is matched to nothing")
    func leavesAPlainFolderUnmatched() {
        #expect(StartProjectPick.project(at: "/tmp/almanac", repos: [repo("harbour")]) == nil)
    }

    @Test("the workspace opened is the first of that project the sidebar draws")
    func opensTheFirstDrawnWorkspace() {
        let rows = [workspace("a", in: "harbour"), workspace("b", in: "harbour")]

        let opened = StartProjectPick.opens(repo: repo("harbour"), workspaces: rows, drawn: { _ in true })

        #expect(opened == WorkspaceID("a"))
    }

    @Test("a workspace the filter leaves out is never opened, so the selection is always drawn")
    func skipsWhatTheFilterLeavesOut() {
        let rows = [workspace("quiet", in: "harbour"), workspace("running", in: "harbour")]

        let opened = StartProjectPick.opens(repo: repo("harbour"), workspaces: rows) {
            $0.id == WorkspaceID("running")
        }

        #expect(opened == WorkspaceID("running"))
    }

    @Test("a workspace of another project is never opened")
    func ignoresOtherProjects() {
        let rows = [workspace("other", in: "beacon")]

        #expect(StartProjectPick.opens(repo: repo("harbour"), workspaces: rows, drawn: { _ in true }) == nil)
    }

    @Test("an archived workspace is not opened, so a project whose work is all archived opens a draft")
    func ignoresArchived() {
        var archived = workspace("gone", in: "harbour")
        archived.state = .archived

        #expect(StartProjectPick.opens(repo: repo("harbour"), workspaces: [archived], drawn: { _ in true }) == nil)
    }

    @Test("a project with nothing drawn opens nothing, and the caller makes a draft")
    func nothingDrawn() {
        let rows = [workspace("a", in: "harbour")]

        #expect(StartProjectPick.opens(repo: repo("harbour"), workspaces: rows, drawn: { _ in false }) == nil)
    }
}
