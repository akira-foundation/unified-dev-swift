import Foundation
import Testing
@testable import Core

@Suite("Branches offered to open")
struct WorkspaceBranchOfferTests {
    private func listing(
        number: Int,
        head: String,
        fork: Bool = false,
        owner: String? = nil
    ) -> PullRequestListing {
        PullRequestListing(
            number: number,
            title: "Fix the parser",
            author: "contributor",
            headRefName: head,
            baseRefName: "main",
            isCrossRepository: fork,
            headRepositoryOwner: owner
        )
    }

    @Test("Local and remote branches merge into one list, the local copy winning")
    func mergesBranches() {
        let branches = WorkspaceCheckoutPlan.offeredBranches(
            local: ["main", "wip"],
            remote: ["origin/main", "origin/wip", "origin/theirs", "origin/HEAD"],
            defaultBranch: "main"
        )
        #expect(branches.map(\.name) == ["main", "theirs", "wip"])
        #expect(branches.first { $0.name == "wip" }?.isLocal == true)
        #expect(branches.first { $0.name == "theirs" }?.isLocal == false)
    }

    @Test("A branch a workspace is already on is still offered, wearing the workspace's name")
    func marksBranchesInUse() {
        let branches = WorkspaceCheckoutPlan.offeredBranches(
            local: ["main", "wip", "review"],
            remote: [],
            defaultBranch: "main",
            inUse: ["review": .workspace("Quiet Harbour")]
        )
        #expect(branches.map(\.name) == ["main", "review", "wip"])
        #expect(branches.first { $0.name == "review" }?.inUseBy == .workspace("Quiet Harbour"))
        #expect(branches.first { $0.name == "wip" }?.inUseBy == nil)
    }

    @Test("The default branch is offered first, wearing the project checkout that holds it")
    func offersTheDefaultBranchFirst() {
        let branches = WorkspaceCheckoutPlan.offeredBranches(
            local: ["alpha", "main"],
            remote: ["origin/main", "origin/beta"],
            defaultBranch: "main",
            inUse: ["main": .projectCheckout(path: "/dev/ember")]
        )
        #expect(branches.map(\.name) == ["main", "alpha", "beta"])
        #expect(branches.first?.inUseBy == .projectCheckout(path: "/dev/ember"))
    }

    @Test("A default branch that exists only on the remote still leads, as a remote branch")
    func leadsWithARemoteDefaultBranch() {
        let branches = WorkspaceCheckoutPlan.offeredBranches(
            local: ["alpha"],
            remote: ["origin/zeta", "origin/alpha"],
            defaultBranch: "zeta"
        )
        #expect(branches.map(\.name) == ["zeta", "alpha"])
        #expect(branches.first?.isLocal == false)
        #expect(branches.first?.remoteName == "origin")
    }

    @Test("Every branch, for a caller that names one, keeps the default branch in the list")
    func keepsEverythingWhenNothingIsBeingOffered() {
        let branches = WorkspaceCheckoutPlan.everyBranch(
            local: ["main", "wip"],
            remote: ["origin/main", "origin/theirs", "origin/HEAD"],
            inUse: ["main": .projectCheckout(path: "/dev/ember")]
        )
        #expect(branches.map(\.name) == ["main", "theirs", "wip"])
        #expect(branches.first { $0.name == "main" }?.inUseBy == .projectCheckout(path: "/dev/ember"))
    }

    @Test("A head with a pull request open on it is offered as the pull request and not twice")
    func skipsBranchesWithAnOpenPullRequest() {
        let requests = [listing(number: 4, head: "figma-mcp-check")]
        let branches = WorkspaceCheckoutPlan.offeredBranches(
            local: ["main", "figma-mcp-check", "wip"],
            remote: ["origin/figma-mcp-check"],
            defaultBranch: "main",
            pullRequestHeads: WorkspaceCheckoutPlan.heads(of: requests)
        )
        #expect(branches.map(\.name) == ["main", "wip"])
    }

    @Test("Being in use does not save a branch from the exclusions that are still right")
    func keepsExcludingWhatAPullRequestSpeaksFor() {
        let requests = [listing(number: 4, head: "figma-mcp-check")]
        let branches = WorkspaceCheckoutPlan.offeredBranches(
            local: ["main", "figma-mcp-check"],
            remote: ["origin/HEAD"],
            defaultBranch: "main",
            inUse: ["figma-mcp-check": .workspace("Coral Bay"), "main": .workspace("Coral Bay")],
            pullRequestHeads: WorkspaceCheckoutPlan.heads(of: requests)
        )
        #expect(branches.map(\.name) == ["main"])
        #expect(branches.first?.inUseBy == .workspace("Coral Bay"))
    }

    @Test("A fork's head does not hide a branch of this repository that shares its name")
    func keepsBranchesSharingAForkHeadName() {
        let requests = [listing(number: 4, head: "patch-1", fork: true, owner: "someone")]
        #expect(WorkspaceCheckoutPlan.heads(of: requests).isEmpty)
        let branches = WorkspaceCheckoutPlan.offeredBranches(
            local: ["main", "patch-1"],
            remote: [],
            defaultBranch: "main",
            pullRequestHeads: WorkspaceCheckoutPlan.heads(of: requests)
        )
        #expect(branches.map(\.name) == ["main", "patch-1"])
    }

    @Test("Only origin's branches count as remote branches")
    func readsRemoteNames() {
        #expect(WorkspaceCheckoutPlan.remoteBranchName("origin/feature/x") == "feature/x")
        #expect(WorkspaceCheckoutPlan.remoteBranchName("upstream/main") == nil)
        #expect(WorkspaceCheckoutPlan.remoteBranchName("origin/HEAD") == nil)
    }
}
