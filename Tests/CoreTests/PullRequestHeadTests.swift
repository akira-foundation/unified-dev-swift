import Foundation
import Testing
@testable import Core

@Suite("Which branch a pull request is looked up by")
struct PullRequestHeadTests {
    @Test("The branch the worktree is on now wins over the one recorded at creation")
    func prefersTheCheckedOutBranch() {
        #expect(
            PullRequestHead.branch(
                recorded: "unifieddev/preview-crash",
                checkedOut: "fix/issue-2069-transactional-mail-admin-preview",
                base: "main"
            ) == "fix/issue-2069-transactional-mail-admin-preview"
        )
    }

    @Test("A detached HEAD leaves the recorded branch as the only name there is")
    func fallsBackWhenDetached() {
        #expect(
            PullRequestHead.branch(recorded: "unifieddev/preview-crash", checkedOut: nil, base: "main")
                == "unifieddev/preview-crash"
        )
        #expect(
            PullRequestHead.branch(recorded: "unifieddev/preview-crash", checkedOut: "  ", base: "main")
                == "unifieddev/preview-crash"
        )
    }

    @Test("A worktree standing on the base branch is not asked about")
    func refusesTheBaseBranch() {
        #expect(
            PullRequestHead.branch(recorded: "unifieddev/preview-crash", checkedOut: "main", base: "main")
                == "unifieddev/preview-crash"
        )
    }

    @Test("A row with no branch name in it is not a name to prefer")
    func toleratesAnEmptyRecord() {
        #expect(PullRequestHead.branch(recorded: "", checkedOut: "main", base: "main") == "main")
        #expect(PullRequestHead.branch(recorded: "", checkedOut: nil, base: "main") == "")
    }
}

@Suite("The branch gh is asked about", .tags(.git), .scratchDirectory)
struct PullRequestHeadBranchTests {
    @Test("A worktree the agent moved to a new branch is looked up under that branch")
    func readsTheBranchOffDisk() async throws {
        let repo = try await TempRepo()
        defer { repo.cleanUp() }

        let workspace = Workspace(
            repoID: RepoID.new(),
            name: "Preview crash",
            branch: "unifieddev/preview-crash",
            path: repo.path,
            baseBranch: "main"
        )

        #expect(await GitHub.headBranch(of: workspace) == "unifieddev/preview-crash")

        try await Shell.check(
            "git", ["checkout", "-q", "-b", "fix/issue-2069-preview"], cwd: repo.path
        )
        #expect(await GitHub.headBranch(of: workspace) == "fix/issue-2069-preview")
    }
}
