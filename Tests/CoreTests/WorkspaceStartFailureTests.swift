import Foundation
import Testing
@testable import Core

@Suite("workspace_start failures", .tags(.git, .subprocess), .scratchDirectory)
struct WorkspaceStartFailureTests {
    private func emptyRepository() async throws -> String {
        let path = TestScratch.unique("unifieddev-git")
        try FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true)
        try await Shell.check("git", ["init", "-q", "-b", "main"], cwd: path)
        return path
    }

    private func failureAddingWorktree(
        repo: String,
        branch: String = "do-thing",
        base: String
    ) async -> (any Error)? {
        do {
            try await Git.addWorktree(
                repo: repo,
                path: TestScratch.unique("worktree") + "/\(branch)",
                branch: branch,
                base: base
            )
            return nil
        } catch {
            return error
        }
    }

    @Test("a repository with no commits says so, rather than blaming the branch name")
    func noCommits() async throws {
        let repo = try await emptyRepository()
        let error = try #require(await failureAddingWorktree(repo: repo, base: "main"))

        #expect(error.readableMessage.contains("invalid reference: main"))

        let trouble = await WorkspaceStartTrouble.diagnose(
            error, project: "ember", projectPath: repo, baseBranch: "main", wasRequested: false
        )

        #expect(trouble == .noCommitsYet(project: "ember"))
        #expect(trouble.sentence.contains("has no commits yet"))
        #expect(trouble.sentence.contains("do not retry with another one"))
        #expect(!trouble.sentence.contains("invalid reference"))
    }

    @Test("a base branch that does not exist names it and names the branches that do")
    func missingBaseBranch() async throws {
        let repo = try await TempRepo()
        try await Shell.check("git", ["branch", "develop"], cwd: repo.path)
        let error = try #require(await failureAddingWorktree(repo: repo.path, base: "no-such-branch"))

        let trouble = await WorkspaceStartTrouble.diagnose(
            error,
            project: "ember",
            projectPath: repo.path,
            baseBranch: "no-such-branch",
            wasRequested: true
        )

        #expect(trouble == .baseBranchMissing(
            branch: "no-such-branch",
            project: "ember",
            wasRequested: true,
            branches: ["develop", "main"]
        ))
        #expect(trouble.sentence.contains("no branch called 'no-such-branch'"))
        #expect(trouble.sentence.contains("'develop' and 'main'"))
        #expect(trouble.sentence.contains("as base_branch"))
    }

    @Test("a missing default branch says it is the default, since the caller never named it")
    func missingDefaultBranch() async throws {
        let repo = try await TempRepo(defaultBranch: "trunk")
        let error = try #require(await failureAddingWorktree(repo: repo.path, base: "main"))

        let trouble = await WorkspaceStartTrouble.diagnose(
            error, project: "ember", projectPath: repo.path, baseBranch: "main", wasRequested: false
        )

        #expect(trouble.sentence.contains("the default branch Unified Dev cuts from"))
        #expect(trouble.sentence.contains("'trunk'"))
    }

    @Test("a project that is gone from disk says the project is gone, not that a file is missing")
    func projectDeleted() async throws {
        let repo = try await TempRepo()
        try FileManager.default.removeItem(atPath: repo.path)
        let error = try #require(await failureAddingWorktree(repo: repo.path, base: "main"))

        #expect(!error.readableMessage.contains(repo.path))

        let trouble = await WorkspaceStartTrouble.diagnose(
            error, project: "ember", projectPath: repo.path, baseBranch: "main", wasRequested: false
        )

        #expect(trouble == .projectMissingFromDisk(project: "ember", path: repo.path))
        #expect(trouble.sentence.contains("no longer on disk"))
        #expect(trouble.sentence.contains("Retrying will not help"))
    }

    @Test("an unrecognised git failure keeps git's words and drops the command line")
    func unexplainedDropsTheCommandLine() async throws {
        let repo = try await TempRepo()
        let error = ShellError(
            command: "git worktree add -b do-thing -- /Users/freek/unifieddev/workspaces/unifieddev-git-711961F7/do-thing main",
            status: 128,
            stderr: "fatal: disk quota exceeded"
        )

        let trouble = await WorkspaceStartTrouble.diagnose(
            error, project: "ember", projectPath: repo.path, baseBranch: "main", wasRequested: false
        )

        #expect(trouble == .unexplained("fatal: disk quota exceeded."))
        #expect(!trouble.sentence.contains("worktree add"))
        #expect(!trouble.sentence.contains("unifieddev-git-711961F7"))
    }

    @Test("no sentence quotes a git command line or an internal worktree path")
    func nothingLeaks() async throws {
        let repo = try await emptyRepository()
        let error = try #require(await failureAddingWorktree(repo: repo, base: "main"))

        let troubles = [
            await WorkspaceStartTrouble.diagnose(
                error, project: "ember", projectPath: repo, baseBranch: "main", wasRequested: false
            ),
            .projectMissingFromDisk(project: "ember", path: "/tmp/ember"),
            .baseBranchMissing(branch: "x", project: "ember", wasRequested: true, branches: ["main"]),
            .noCommitsYet(project: "ember"),
        ] as [WorkspaceStartTrouble]

        for trouble in troubles {
            #expect(!trouble.sentence.contains("git worktree"))
            #expect(!trouble.sentence.contains("exited 128"))
            #expect(!trouble.sentence.contains("workspaces/unifieddev-git"))
        }
    }

    @Test("a project with no branches at all is a sentence rather than a crash")
    func noBranchesAtAll() {
        let sentence = WorkspaceStartTrouble.baseBranchMissing(
            branch: "main", project: "ember", wasRequested: false, branches: []
        ).sentence

        #expect(sentence.contains("no branches at all"))
        #expect(sentence.contains("Do not retry"))
        #expect(!sentence.isEmpty)
    }

    @Test("one branch reads as one, and two read as a pair")
    func listsSmallCounts() {
        func sentence(_ branches: [String]) -> String {
            WorkspaceStartTrouble.baseBranchMissing(
                branch: "nope", project: "ember", wasRequested: true, branches: branches
            ).sentence
        }
        #expect(sentence(["main"]).contains("Its only branch is 'main'."))
        #expect(sentence(["main", "wip"]).contains("Its branches are 'main' and 'wip'."))
    }

    @Test("the branch listing is capped")
    func branchListingIsCapped() {
        let branches = (1...25).map { "feature/\($0)" }
        let sentence = WorkspaceStartTrouble.baseBranchMissing(
            branch: "nope", project: "ember", wasRequested: true, branches: branches
        ).sentence

        #expect(sentence.contains("and 15 more"))
        #expect(!sentence.contains("feature/20"))
    }
}
