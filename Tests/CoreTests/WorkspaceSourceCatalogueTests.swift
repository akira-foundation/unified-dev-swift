import Foundation
import Testing
@testable import Core

@Suite("What the starting point offers, built once")
struct WorkspaceSourceCatalogueTests {
    private func listing(
        local: [String] = ["main", "bell"],
        remote: [String] = ["origin/main", "origin/colleague/idea", "origin/Zeta", "origin/HEAD"],
        remoteNames: [String] = ["origin"],
        worktrees: [WorktreeEntry] = []
    ) -> WorkspaceBranchListing {
        WorkspaceBranchListing(local: local, remote: remote, remoteNames: remoteNames, worktrees: worktrees)
    }

    @Test("the bases are every local and primary remote branch, sorted the way Finder sorts, once")
    func basesAreSortedOnce() {
        let catalogue = WorkspaceSourceCatalogue(
            listing: listing(), defaultBranch: "main", projectPath: "/repo", workspaceNames: [:]
        )
        #expect(catalogue.baseBranches == ["bell", "colleague/idea", "main", "Zeta"])
        #expect(catalogue.offering.baseBranches == catalogue.baseBranches)
    }

    @Test("the existing branches come from the same listing as the bases")
    func existingFromTheSameListing() {
        let catalogue = WorkspaceSourceCatalogue(
            listing: listing(), defaultBranch: "main", projectPath: "/repo", workspaceNames: [:]
        )
        let names = catalogue.offering.branches.map(\.name)
        #expect(Set(names).isSubset(of: Set(catalogue.baseBranches)))
        #expect(names.contains("colleague/idea"))
        #expect(!names.contains("main"))
    }

    @Test("a branch a workspace holds is marked with who holds it")
    func holdersAreMarked() {
        let worktree = WorktreeEntry(path: "/ws/bell", head: "abc", branch: "bell")
        let catalogue = WorkspaceSourceCatalogue(
            listing: listing(worktrees: [worktree]),
            defaultBranch: "main",
            projectPath: "/repo",
            workspaceNames: ["bell": "Bell"]
        )
        #expect(catalogue.holders["bell"] == .workspace("Bell"))
        #expect(catalogue.offering.branches.first { $0.name == "bell" }?.inUseBy == .workspace("Bell"))
    }

    @Test("pull requests arriving later take their heads out of the existing branches")
    func pullRequestsArriveLater() {
        let catalogue = WorkspaceSourceCatalogue(
            listing: listing(), defaultBranch: "main", projectPath: "/repo", workspaceNames: [:]
        )
        let request = PullRequestListing(number: 13, title: "Idea", headRefName: "colleague/idea", baseRefName: "main")
        let later = catalogue.with(pullRequests: [request])
        #expect(later.offering.pullRequests == [request])
        #expect(!later.offering.branches.map(\.name).contains("colleague/idea"))
        #expect(later.baseBranches == catalogue.baseBranches)
    }

    @Test("a base the primary remote has reads as that remote's, a local one does not")
    func remoteOfABase() {
        let catalogue = WorkspaceSourceCatalogue(
            listing: listing(), defaultBranch: "main", projectPath: "/repo", workspaceNames: [:]
        )
        #expect(catalogue.remote(of: "main") == "origin")
        #expect(catalogue.remote(of: "bell") == nil)
        #expect(catalogue.offersPullRequests)
    }

    @Test("a project with no remote offers no pull requests and its default branch still")
    func noRemote() {
        let catalogue = WorkspaceSourceCatalogue(
            listing: listing(local: ["main"], remote: [], remoteNames: []),
            defaultBranch: "main", projectPath: "/repo", workspaceNames: [:]
        )
        #expect(catalogue.primaryRemote == nil)
        #expect(!catalogue.offersPullRequests)
        #expect(catalogue.baseBranches == ["main"])
        #expect(catalogue.remote(of: "main") == nil)
    }

    @Test("an empty repository still offers its default branch as a base")
    func emptyRepository() {
        let catalogue = WorkspaceSourceCatalogue(
            listing: listing(local: [], remote: [], remoteNames: []),
            defaultBranch: "main", projectPath: "/repo", workspaceNames: [:]
        )
        #expect(catalogue.baseBranches == ["main"])
    }
}

@Suite("Why there are no pull requests")
struct PullRequestLoadTests {
    @Test("each reason has its own sentence, and a list has none")
    func sentences() {
        #expect(PullRequestLoad.from(access: .notInstalled, failure: nil, requests: []).note
            == "Install the GitHub CLI to list pull requests")
        #expect(PullRequestLoad.from(access: .signedOut, failure: nil, requests: []).note
            == "Sign in with gh to list pull requests")
        #expect(PullRequestLoad.from(access: .ready, failure: "rate limited", requests: []).note == "rate limited")
        #expect(PullRequestLoad.from(access: .ready, failure: nil, requests: []).note == "No open pull requests")
        #expect(PullRequestLoad.loading.note == "Loading pull requests")
        let request = PullRequestListing(number: 1, title: "t", headRefName: "h", baseRefName: "main")
        #expect(PullRequestLoad.from(access: .ready, failure: nil, requests: [request]).note == nil)
        #expect(PullRequestLoad.from(access: .ready, failure: nil, requests: [request]).requests == [request])
    }
}

@Suite("The starting point against a real remote", .tags(.git), .scratchDirectory)
struct WorkspaceSourceCatalogueRemoteTests {
    @Test("one read lists a branch only the remote has, as a base and as an existing branch")
    func oneReadServesBoth() async throws {
        let server = try await TempRepo()
        defer { server.cleanUp() }
        try await Shell.check("git", ["branch", "colleague/idea"], cwd: server.path)
        let work = try await TempRepo.clone(of: server, named: "catalogue-remote")
        defer { work.cleanUp() }

        let repo = Repo(name: "catalogue-remote", path: work.path, defaultBranch: "main")
        let catalogue = await WorkspaceSourceCatalogue.load(repo: repo, workspaces: [])

        #expect(catalogue.primaryRemote == "origin")
        #expect(catalogue.baseBranches.contains("colleague/idea"))
        #expect(catalogue.offering.branches.contains { $0.name == "colleague/idea" && !$0.isLocal })
        guard case .projectCheckout = catalogue.holders["main"] else {
            Issue.record("the project's own checkout should hold main")
            return
        }
    }
}
