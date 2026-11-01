import Testing
import Foundation
@testable import Core

@Suite("Archive unpublished commits", .tags(.git, .destructive), .scratchDirectory)
struct ArchiveUnpublishedCommitsTests {
    private func makeWorkspace() async throws -> (TempRepo, Repo, WorkspaceManager, Workspace) {
        let repo = try await TempRepo()
        let manager = WorkspaceManager(store: try makeTestStore("unpublished"))
        let registered = try await manager.addRepository(at: repo.path)
        let workspace = try await manager.createWorkspace(repo: registered, prompt: "Do the thing")
        return (repo, registered, manager, workspace)
    }

    private func squashMerge(_ branch: String, into repo: TempRepo) async throws {
        try await Shell.check("git", ["merge", "--squash", branch], cwd: repo.path)
        try await repo.commit("the feature (#7)")
    }

    @Test("a merged pull request excuses the commits it carried")
    func mergedPullRequestExcusesItsOwnCommits() async throws {
        let (repo, registered, manager, workspace) = try await makeWorkspace()
        defer { repo.cleanUp() }

        let worktree = TempRepo(existing: workspace.path)
        try worktree.write("feature.txt", "the feature\n")
        try await worktree.commit("the feature")
        let head = try await Git.headSHA(of: workspace.path)
        try await squashMerge(workspace.branch, into: repo)

        let report = try await manager.safetyReport(
            workspace: workspace, repo: registered, mergedPullRequestHead: head
        )
        #expect(report.unpushedCommits == 1)
        #expect(report.isSafeToDiscard(deletingBranch: true, isPullRequestMerged: true))

        try await manager.archive(
            workspace: workspace, repo: registered, deleteBranch: true, mergedPullRequestHead: head
        )
        #expect(await Git.branchExists(workspace.branch, in: repo.path) == false)
    }

    @Test("commits made after the pull request merged still count as lost")
    func commitsAfterTheMergeAreNotExcused() async throws {
        let (repo, registered, manager, workspace) = try await makeWorkspace()
        defer { repo.cleanUp() }

        let worktree = TempRepo(existing: workspace.path)
        try worktree.write("feature.txt", "the feature\n")
        try await worktree.commit("the feature")
        let head = try await Git.headSHA(of: workspace.path)
        try await squashMerge(workspace.branch, into: repo)
        try worktree.write("follow-up.txt", "written after the merge\n")
        try await worktree.commit("the follow-up")
        let followUp = try await Git.headSHA(of: workspace.path)

        let report = try await manager.safetyReport(
            workspace: workspace, repo: registered, mergedPullRequestHead: head
        )
        #expect(report.isSafeToDiscard(deletingBranch: true, isPullRequestMerged: true) == false)
        #expect(report.irreversibleLosses(deletingBranch: true, isPullRequestMerged: true) == [
            "1 commit that exists on no other branch, tag or remote",
        ])

        await #expect(throws: WorkspaceError.self) {
            try await manager.archive(
                workspace: workspace, repo: registered, deleteBranch: true, mergedPullRequestHead: head
            )
        }
        let kept = try await Shell.check(
            "git", ["rev-parse", "refs/heads/\(workspace.branch)"], cwd: repo.path
        )
        #expect(kept.trimmed == followUp)
    }

    @Test("a merged pull request whose head is unknown excuses nothing")
    func unknownPullRequestHeadExcusesNothing() async throws {
        let (repo, registered, manager, workspace) = try await makeWorkspace()
        defer { repo.cleanUp() }

        let worktree = TempRepo(existing: workspace.path)
        try worktree.write("feature.txt", "the feature\n")
        try await worktree.commit("the feature")
        try await squashMerge(workspace.branch, into: repo)

        let unknown = String(repeating: "e", count: 40)
        let report = try await manager.safetyReport(
            workspace: workspace, repo: registered, mergedPullRequestHead: unknown
        )
        #expect(report.isSafeToDiscard(deletingBranch: true, isPullRequestMerged: true) == false)

        await #expect(throws: WorkspaceError.self) {
            try await manager.archive(
                workspace: workspace, repo: registered, deleteBranch: true, mergedPullRequestHead: unknown
            )
        }
        #expect(await Git.branchExists(workspace.branch, in: repo.path))
    }

    @Test("a remote-tracking ref whose branch is gone from the server holds nothing")
    func staleRemoteTrackingRefIsNoCopy() async throws {
        let (repo, registered, manager, workspace) = try await makeWorkspace()
        defer { repo.cleanUp() }

        let remote = TestScratch.unique("unifieddev-remote") + ".git"
        try await Shell.check("git", ["init", "-q", "--bare", remote])
        try await Shell.check("git", ["remote", "add", "origin", remote], cwd: repo.path)

        let worktree = TempRepo(existing: workspace.path)
        try worktree.write("feature.txt", "pushed, then deleted on the server\n")
        try await worktree.commit("the feature")
        try await GitHub.push(worktree: workspace.path, branch: workspace.branch, setUpstream: true)
        try await Shell.check("git", ["--git-dir", remote, "branch", "-D", workspace.branch])

        let report = try await manager.safetyReport(workspace: workspace, repo: registered)
        #expect(report.unpushedCommits == 1)
        #expect(report.isSafeToDiscard(deletingBranch: true) == false)

        await #expect(throws: WorkspaceError.self) {
            try await manager.archive(workspace: workspace, repo: registered, deleteBranch: true)
        }
        #expect(await Git.branchExists(workspace.branch, in: repo.path))
    }

    @Test("an unreachable remote keeps its remote-tracking refs as copies")
    func unreachableRemoteKeepsItsRefs() async throws {
        let (repo, registered, manager, workspace) = try await makeWorkspace()
        defer { repo.cleanUp() }

        let remote = TestScratch.unique("unifieddev-remote") + ".git"
        try await Shell.check("git", ["init", "-q", "--bare", remote])
        try await Shell.check("git", ["remote", "add", "origin", remote], cwd: repo.path)

        let worktree = TempRepo(existing: workspace.path)
        try worktree.write("feature.txt", "pushed while the remote was there\n")
        try await worktree.commit("the feature")
        try await GitHub.push(worktree: workspace.path, branch: workspace.branch, setUpstream: true)
        try FileManager.default.removeItem(atPath: remote)

        let report = try await manager.safetyReport(workspace: workspace, repo: registered)
        #expect(report.unpushedCommits == 0)
        let tracking = try await Shell.check(
            "git", ["for-each-ref", "--format=%(refname)", "refs/remotes/origin"], cwd: repo.path
        )
        #expect(tracking.stdout.contains("refs/remotes/origin/\(workspace.branch)"))
    }
}
