import Testing
import Foundation
@testable import Core

@Suite("Archive gate", .tags(.git), .scratchDirectory)
struct ArchiveGateTests {
    @Test("a clean worktree with no commits of its own is safe either way")
    func cleanAndEmptyIsSafe() {
        let report = WorkspaceSafetyReport()
        #expect(report.isSafeToDiscard(deletingBranch: true))
        #expect(report.isSafeToDiscard(deletingBranch: false))
        #expect(report.losses(deletingBranch: true).isEmpty)
    }

    @Test("commits of its own only matter when the branch goes too")
    func commitsMatterOnlyWhenDeletingTheBranch() {
        let report = WorkspaceSafetyReport(unpushedCommits: 3)

        #expect(report.isSafeToDiscard(deletingBranch: false))
        #expect(report.losses(deletingBranch: false).isEmpty)

        #expect(report.isSafeToDiscard(deletingBranch: true) == false)
        #expect(report.losses(deletingBranch: true).count == 1)
    }

    @Test("a merged pull request answers for the commits when git cannot")
    func mergedPullRequestClearsTheCommits() {
        let report = WorkspaceSafetyReport(unpushedCommits: 3, isBranchMerged: false)

        #expect(report.isSafeToDiscard(deletingBranch: true) == false)
        #expect(report.isSafeToDiscard(deletingBranch: true, isPullRequestMerged: true))
        #expect(report.losses(deletingBranch: true, isPullRequestMerged: true).isEmpty)
    }

    @Test("a merged pull request never excuses work that was never committed")
    func mergedPullRequestDoesNotExcuseTheWorkingCopy() {
        for report in [
            WorkspaceSafetyReport(hasUncommittedChanges: true),
            WorkspaceSafetyReport(untrackedFiles: ["plan.md"]),
            WorkspaceSafetyReport(modifiedIgnoredFiles: [".env"]),
            WorkspaceSafetyReport(detachedCommits: 2),
        ] {
            #expect(report.isSafeToDiscard(deletingBranch: true, isPullRequestMerged: true) == false)
            #expect(report.isSafeToDiscard(deletingBranch: false, isPullRequestMerged: true) == false)
        }
    }

    @Test("commits made on a detached HEAD are not in anybody's pull request")
    func detachedCommitsAreNeverExcused() {
        let report = WorkspaceSafetyReport(detachedCommits: 1)
        #expect(report.isSafeToDiscard(deletingBranch: false) == false)
        #expect(report.losses(deletingBranch: false).contains { $0.contains("detached HEAD") })
    }

    @Test("the plain property is still the cautious answer")
    func thePlainPropertyAssumesTheBranchGoes() {
        let report = WorkspaceSafetyReport(unpushedCommits: 1)
        #expect(report.isSafeToDiscard == false)
        #expect(report.isSafeToDiscard == report.isSafeToDiscard(deletingBranch: true))
        #expect(report.losses == report.losses(deletingBranch: true))
    }

    private func makeWorkspace() async throws
        -> (repo: TempRepo, registered: Repo, manager: WorkspaceManager, workspace: Workspace) {
        let repo = try await TempRepo()
        let manager = WorkspaceManager(store: try makeTestStore("archive-gate"))
        let registered = try await manager.addRepository(at: repo.path)
        let workspace = try await manager.createWorkspace(repo: registered, prompt: "Do the thing")
        return (repo, registered, manager, workspace)
    }

    private func commit(in worktree: String, message: String) async throws {
        try await Shell.check("git", ["add", "-A"], cwd: worktree)
        try await Shell.check("git", [
            "-c", "user.email=test@unifieddev.local", "-c", "user.name=Unified Dev Test",
            "-c", "commit.gpgsign=false",
            "commit", "-q", "-m", message,
        ], cwd: worktree)
    }

    @Test("keeping the branch archives a workspace whose commits exist nowhere else", .tags(.destructive))
    func keepingTheBranchNeedsNoConfirmation() async throws {
        let (repo, registered, manager, workspace) = try await makeWorkspace()
        defer { repo.cleanUp() }

        try TempRepo(existing: workspace.path).write("feature.txt", "work that exists nowhere else\n")
        try await commit(in: workspace.path, message: "unpublished work")

        let report = try await manager.safetyReport(workspace: workspace, repo: registered)
        #expect(report.unpushedCommits == 1)
        #expect(report.isBranchMerged == false)

        await #expect(throws: WorkspaceError.self) {
            try await manager.archive(workspace: workspace, repo: registered, deleteBranch: true)
        }

        try await manager.archive(workspace: workspace, repo: registered, deleteBranch: false)
        #expect(FileManager.default.fileExists(atPath: workspace.path) == false)
        #expect(await Git.branchExists(workspace.branch, in: repo.path))
    }

    @Test("a workspace whose worktree is gone keeps its branch", .tags(.destructive))
    func aMissingWorktreeKeepsItsBranch() async throws {
        let (repo, registered, manager, workspace) = try await makeWorkspace()
        defer { repo.cleanUp() }

        try await Git.removeWorktree(repo: repo.path, path: workspace.path, force: true)
        #expect(FileManager.default.fileExists(atPath: workspace.path) == false)
        #expect(await Git.branchExists(workspace.branch, in: repo.path))

        try await manager.archive(workspace: workspace, repo: registered, deleteBranch: true)

        #expect(await Git.branchExists(workspace.branch, in: repo.path))
    }

    @Test("a squash merged branch is refused by git alone and cleared by GitHub", .tags(.destructive))
    func squashMergeIsClearedByThePullRequest() async throws {
        let (repo, registered, manager, workspace) = try await makeWorkspace()
        defer { repo.cleanUp() }

        let worktree = TempRepo(existing: workspace.path)
        try worktree.write("feature.txt", "the whole feature\n")
        try await commit(in: workspace.path, message: "the feature")

        try await Shell.check("git", ["merge", "--squash", workspace.branch], cwd: repo.path)
        try await Shell.check(
            "git",
            [
                "-c", "user.email=test@unifieddev.local", "-c", "user.name=Unified Dev Test",
                "-c", "commit.gpgsign=false",
                "commit", "-q", "-m", "the feature (#7)",
            ],
            cwd: repo.path
        )

        let report = try await manager.safetyReport(workspace: workspace, repo: registered)
        #expect(report.isBranchMerged == false, "git cannot see a squash merge")
        #expect(report.unpushedCommits == 1)
        #expect(report.isSafeToDiscard(deletingBranch: true) == false)

        await #expect(throws: WorkspaceError.self) {
            try await manager.archive(workspace: workspace, repo: registered, deleteBranch: true)
        }

        try await manager.archive(
            workspace: workspace, repo: registered, deleteBranch: true, isPullRequestMerged: true
        )
        #expect(FileManager.default.fileExists(atPath: workspace.path) == false)
        #expect(await Git.branchExists(workspace.branch, in: repo.path) == false)
    }

    @Test("a merged pull request does not archive over uncommitted work", .tags(.destructive))
    func mergedPullRequestStillRefusesADirtyWorktree() async throws {
        let (repo, registered, manager, workspace) = try await makeWorkspace()
        defer { repo.cleanUp() }

        let worktree = TempRepo(existing: workspace.path)
        try worktree.write("README.md", "hello\nedited after the merge\n")

        await #expect(throws: WorkspaceError.self) {
            try await manager.archive(
                workspace: workspace, repo: registered, deleteBranch: true, isPullRequestMerged: true
            )
        }
        #expect(worktree.read("README.md") == "hello\nedited after the merge\n")
    }
}
