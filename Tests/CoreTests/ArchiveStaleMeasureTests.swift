import Testing
import Foundation
@testable import Core

@Suite("A branch whose safety is gone by the time the archive deletes it", .tags(.git, .destructive), .scratchDirectory)
struct ArchiveStaleMeasureTests {
    private static let removesTheRemoteBranch = """
    [scripts]
    archive = '''
    git push -q origin --delete "$(git rev-parse --abbrev-ref HEAD)"
    '''
    """

    private func makePushedWorkspace(
        script: String = Self.removesTheRemoteBranch
    ) async throws -> (TempRepo, Repo, WorkspaceManager, Workspace, String) {
        let repo = try await TempRepo()
        let remote = TestScratch.unique("unifieddev-remote") + ".git"
        try await Shell.check("git", ["init", "-q", "--bare", remote])
        try await Shell.check("git", ["remote", "add", "origin", remote], cwd: repo.path)
        try repo.write(".conductor/settings.toml", script)
        let manager = WorkspaceManager(store: try makeTestStore("stale-measure"))
        let registered = try await manager.addRepository(at: repo.path)
        let workspace = try await manager.createWorkspace(repo: registered, prompt: "Do the thing")
        let worktree = TempRepo(existing: workspace.path)
        try worktree.write("work.txt", "held only by the remote branch\n")
        try await worktree.commit("the work")
        try await Shell.check("git", ["push", "-q", "origin", "HEAD:refs/heads/\(workspace.branch)"], cwd: workspace.path)
        let tip = try await Git.headSHA(of: workspace.path)
        return (repo, registered, manager, workspace, tip)
    }

    @Test("a script that removes the only other copy keeps the branch", arguments: [false, true])
    func scriptRemovingTheRemoteKeepsTheBranch(force: Bool) async throws {
        let (repo, registered, manager, workspace, tip) = try await makePushedWorkspace()
        defer { repo.cleanUp() }

        try await manager.archive(workspace: workspace, repo: registered, deleteBranch: true, force: force)

        let kept = await Git.revision(of: "refs/heads/\(workspace.branch)", in: repo.path)
        #expect(kept == tip)
        #expect(try await manager.store.workspace(id: workspace.id)?.state == .archived)
    }

    @Test("a confirmed loss still deletes exactly what was shown")
    func confirmedLossStillDeletes() async throws {
        let repo = try await TempRepo()
        defer { repo.cleanUp() }
        let manager = WorkspaceManager(store: try makeTestStore("stale-measure"))
        let registered = try await manager.addRepository(at: repo.path)
        let workspace = try await manager.createWorkspace(repo: registered, prompt: "Do the thing")
        let worktree = TempRepo(existing: workspace.path)
        try worktree.write("work.txt", "shown in the confirmation\n")
        try await worktree.commit("the work")

        try await manager.archive(workspace: workspace, repo: registered, deleteBranch: true, force: true)

        #expect(await Git.branchExists(workspace.branch, in: repo.path) == false)
    }

    @Test("a loss larger than the one confirmed keeps the branch")
    func aLargerLossThanConfirmedKeepsTheBranch() async throws {
        let (repo, registered, manager, workspace, _) = try await makePushedWorkspace()
        defer { repo.cleanUp() }
        let worktree = TempRepo(existing: workspace.path)
        try worktree.write("more.txt", "local only, and shown\n")
        try await worktree.commit("more work")
        let tip = try await Git.headSHA(of: workspace.path)

        try await manager.archive(workspace: workspace, repo: registered, deleteBranch: true, force: true)

        #expect(await Git.revision(of: "refs/heads/\(workspace.branch)", in: repo.path) == tip)
    }

    @Test("a merged pull request's head is still held after the script removes the remote")
    func aMergedPullRequestLetsTheBranchGo() async throws {
        let (repo, registered, manager, workspace, tip) = try await makePushedWorkspace()
        defer { repo.cleanUp() }

        try await manager.archive(
            workspace: workspace, repo: registered, deleteBranch: true, mergedPullRequestHead: tip
        )

        #expect(await Git.branchExists(workspace.branch, in: repo.path) == false)
    }
}
