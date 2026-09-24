import Testing
@testable import Core

@Suite("The default branch in the starting point popover")
struct StartingPointDefaultBranchTests {
    private let repoID = RepoID("anchorage")

    private var catalogue: WorkspaceSourceCatalogue {
        WorkspaceSourceCatalogue(
            listing: WorkspaceBranchListing(
                local: ["main", "bell", "lamp"],
                remote: ["origin/main", "origin/bell", "origin/lamp", "origin/HEAD"],
                remoteNames: ["origin"],
                worktrees: [
                    WorktreeEntry(path: "/dev/anchorage", head: "abc", branch: "main"),
                    WorktreeEntry(path: "/ws/bell", head: "def", branch: "bell"),
                ]
            ),
            defaultBranch: "main",
            projectPath: "/dev/anchorage",
            workspaceNames: ["bell": "Bell"]
        )
    }

    private func existing(query: String) -> [WorkspaceSource] {
        let sections = StartingPointMenu.sections(
            offering: catalogue.offering, query: query, leadingBase: nil, offersPullRequests: true
        )
        return sections.first { $0.kind == .existingBranch }?.rows ?? []
    }

    @Test("with nothing typed, the default branch leads Existing branch, marked as the project's")
    func leadsTheSection() {
        let rows = existing(query: "")
        #expect(rows.map(\.name) == ["main", "bell", "lamp"])
        #expect(rows.first?.note == "Checked out in the project")
    }

    @Test("typing the default branch's name finds it under Existing branch")
    func searchFindsIt() {
        #expect(existing(query: "main").first?.name == "main")
    }

    @Test("choosing it while the project is on it is refused, pointing at New branch from")
    func choosingItIsRefused() {
        let catalogue = self.catalogue
        guard let main = existing(query: "").first else {
            Issue.record("the default branch was not offered")
            return
        }
        let pick = StartingPointPick.decide(
            main, holders: catalogue.holders, taken: catalogue.localBranches, repoID: repoID, workspaces: []
        )
        let holder = BranchHolder.projectCheckout(path: "/dev/anchorage")
        #expect(pick == .refuse(holder.refusal(branch: "main")))
        #expect(holder.refusal(branch: "main").contains("New branch from"))
    }
}
