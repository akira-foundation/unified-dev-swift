import Testing
import Foundation
@testable import Core

@Suite("A commit that arrives while the archive runs", .tags(.git, .destructive), .scratchDirectory)
struct ArchiveLateCommitTests {
    private static let committingScript = """
    [scripts]
    archive = '''
    echo "written by the archive script" > late.txt
    git add late.txt
    git -c commit.gpgsign=false commit -q -m "late commit"
    git rev-parse HEAD > "$UD_ROOT_PATH/.late-commit"
    '''
    """

    private func makeWorkspace() async throws -> (TempRepo, Repo, WorkspaceManager, Workspace) {
        let repo = try await TempRepo()
        try repo.write(".conductor/settings.toml", Self.committingScript)
        let manager = WorkspaceManager(store: try makeTestStore("late-commit"))
        let registered = try await manager.addRepository(at: repo.path)
        let workspace = try await manager.createWorkspace(repo: registered, prompt: "Do the thing")
        return (repo, registered, manager, workspace)
    }

    @Test("archive anyway keeps a branch that gained a commit after it was measured", arguments: [true, false])
    func keepsTheBranchWithTheLateCommit(force: Bool) async throws {
        let (repo, registered, manager, workspace) = try await makeWorkspace()
        defer { repo.cleanUp() }

        try await manager.archive(workspace: workspace, repo: registered, deleteBranch: true, force: force)

        let late = try #require(repo.read(".late-commit")).trimmingCharacters(in: .whitespacesAndNewlines)
        let tip = try await Shell.check("git", ["rev-parse", "refs/heads/\(workspace.branch)"], cwd: repo.path)
        #expect(tip.trimmed == late)
        #expect(try await manager.store.workspace(id: workspace.id)?.state == .archived)
    }

    @Test("a commit made after the report and before the archive keeps the branch")
    func aCommitBetweenTheReportAndTheArchiveKeepsTheBranch() async throws {
        let repo = try await TempRepo()
        defer { repo.cleanUp() }
        let manager = WorkspaceManager(store: try makeTestStore("late-commit"))
        let registered = try await manager.addRepository(at: repo.path)
        let workspace = try await manager.createWorkspace(repo: registered, prompt: "Do the thing")

        let report = try await manager.safetyReport(workspace: workspace, repo: registered)
        let worktree = TempRepo(existing: workspace.path)
        try worktree.write("late.txt", "after the report\n")
        try await worktree.commit("late commit")
        let late = try await Git.headSHA(of: workspace.path)

        try await manager.archive(
            workspace: workspace, repo: registered, deleteBranch: true, force: true,
            measuredTip: report.branchTip
        )

        let tip = try await Shell.check("git", ["rev-parse", "refs/heads/\(workspace.branch)"], cwd: repo.path)
        #expect(tip.trimmed == late)
    }

    @Test("a late commit already on a remote does not stop the branch going")
    func aLateCommitOnARemoteLetsTheBranchGo() async throws {
        let repo = try await TempRepo()
        defer { repo.cleanUp() }
        let remote = TestScratch.unique("unifieddev-remote") + ".git"
        try await Shell.check("git", ["init", "-q", "--bare", remote])
        try await Shell.check("git", ["remote", "add", "origin", remote], cwd: repo.path)
        try repo.write(".conductor/settings.toml", """
        [scripts]
        archive = '''
        echo "written by the archive script" > late.txt
        git add late.txt
        git -c commit.gpgsign=false commit -q -m "late commit"
        git push -q origin "HEAD:refs/heads/kept-elsewhere"
        '''
        """)
        let manager = WorkspaceManager(store: try makeTestStore("late-commit"))
        let registered = try await manager.addRepository(at: repo.path)
        let workspace = try await manager.createWorkspace(repo: registered, prompt: "Do the thing")

        try await manager.archive(workspace: workspace, repo: registered, deleteBranch: true, force: true)

        #expect(await Git.branchExists(workspace.branch, in: repo.path) == false)
    }

    @Test("a forced deletion goes ahead only for commits it was shown or that are held elsewhere")
    func forcedDeletionFollowsWhatWasMeasured() {
        #expect(ArchiveBranchDeletion.forcesDeletion(
            tipUnchanged: true, clearedAtStart: false, force: true, lostNow: nil
        ))
        #expect(ArchiveBranchDeletion.forcesDeletion(
            tipUnchanged: true, clearedAtStart: true, force: false, lostNow: nil
        ))
        #expect(ArchiveBranchDeletion.forcesDeletion(
            tipUnchanged: false, clearedAtStart: false, force: true, lostNow: 0
        ))
        #expect(ArchiveBranchDeletion.forcesDeletion(
            tipUnchanged: false, clearedAtStart: true, force: true, lostNow: 1
        ) == false)
        #expect(ArchiveBranchDeletion.forcesDeletion(
            tipUnchanged: false, clearedAtStart: true, force: true, lostNow: nil
        ) == false)
        #expect(ArchiveBranchDeletion.forcesDeletion(
            tipUnchanged: true, clearedAtStart: false, force: false, lostNow: nil
        ) == false)
    }
}
