import Foundation
import Testing
@testable import Core

@Suite("Base of a workspace diff", .tags(.git), .scratchDirectory)
struct BaselineTests {
    private func clone(of server: TempRepo, named name: String) async throws -> TempRepo {
        let path = TestScratch.unique(name)
        try await Shell.check("git", ["clone", "-q", server.path, path])
        try await Shell.check("git", ["config", "user.email", "test@unifieddev.local"], cwd: path)
        try await Shell.check("git", ["config", "user.name", "Unified Dev Test"], cwd: path)
        try await Shell.check("git", ["config", "commit.gpgsign", "false"], cwd: path)
        return TempRepo(existing: path)
    }

    private func commitAll(_ repo: TempRepo, _ message: String) async throws {
        try await Shell.check("git", ["add", "-A"], cwd: repo.path)
        try await Shell.check("git", ["commit", "-q", "-m", message], cwd: repo.path)
    }

    @Test("after a squash merge and Continue, the merged files are not this workspace's changes")
    func continuedAfterASquashMerge() async throws {
        let server = try await TempRepo()
        defer { server.cleanUp() }
        let work = try await clone(of: server, named: "worktree")
        defer { work.cleanUp() }

        let cutFrom = try await Git.headSHA(of: work.path)

        try await Shell.check("git", ["checkout", "-q", "-b", "tasklist"], cwd: work.path)
        for name in ["src/a.swift", "src/b.swift", "tests/a.swift", "tests/b.swift", "README.md"] {
            try work.write(name, "the work\n")
        }
        try await commitAll(work, "add the tasklist")

        for name in ["src/a.swift", "src/b.swift", "tests/a.swift", "tests/b.swift", "README.md"] {
            try server.write(name, "the work\n")
        }
        try await commitAll(server, "add the tasklist (#2)")

        let resolved = try await Git.baseRevision(branch: "main", in: work.path)
        #expect(resolved.base == .fetched)
        try await Git.checkoutNewBranch("tasklist-2", at: resolved.revision, in: work.path)

        #expect(await Git.revision(of: "refs/heads/main", in: work.path) == cutFrom)

        let files = try await Git.changedFiles(worktree: work.path, base: "main")
        #expect(files.isEmpty, "still reported \(files.map(\.path))")

        try work.write("src/c.swift", "the next thing\n")
        let after = try await Git.changedFiles(worktree: work.path, base: "main")
        #expect(after.map(\.path) == ["src/c.swift"])
    }

    @Test("unpushed commits on the local base are not counted as the workspace's work")
    func unpushedCommitsOnTheLocalBase() async throws {
        let server = try await TempRepo()
        defer { server.cleanUp() }
        let work = try await clone(of: server, named: "worktree")
        defer { work.cleanUp() }

        try work.write("notes-from-the-user.md", "written on main and never pushed\n")
        try await commitAll(work, "a commit of my own")

        try await Shell.check("git", ["checkout", "-q", "-b", "feature"], cwd: work.path)
        try work.write("src/feature.swift", "the agent's work\n")
        try await commitAll(work, "the agent's work")

        let files = try await Git.changedFiles(worktree: work.path, base: "main")
        #expect(files.map(\.path) == ["src/feature.swift"])
    }

    @Test("a base branch with no remote-tracking copy still answers")
    func noRemoteAtAll() async throws {
        let repo = try await TempRepo()
        defer { repo.cleanUp() }

        let head = try await Git.headSHA(of: repo.path)
        try await Shell.check("git", ["checkout", "-q", "-b", "feature"], cwd: repo.path)
        try repo.write("src/feature.swift", "work\n")
        try await commitAll(repo, "work")

        #expect(try await Git.baseline("main", in: repo.path) == head)
        let files = try await Git.changedFiles(worktree: repo.path, base: "main")
        #expect(files.map(\.path) == ["src/feature.swift"])
    }

    @Test("a base branch that was never pushed is not an error")
    func baseBranchWithNoUpstream() async throws {
        let server = try await TempRepo()
        defer { server.cleanUp() }
        let work = try await clone(of: server, named: "worktree")
        defer { work.cleanUp() }

        try await Shell.check("git", ["checkout", "-q", "-b", "release"], cwd: work.path)
        try work.write("release-notes.md", "2.0\n")
        try await commitAll(work, "start the release branch")
        let releaseTip = try await Git.headSHA(of: work.path)

        try await Shell.check("git", ["checkout", "-q", "-b", "hotfix"], cwd: work.path)
        try work.write("src/fix.swift", "the fix\n")
        try await commitAll(work, "the fix")

        #expect(try await Git.baseline("release", in: work.path) == releaseTip)
        let files = try await Git.changedFiles(worktree: work.path, base: "release")
        #expect(files.map(\.path) == ["src/fix.swift"])
    }

    @Test("a base that exists nowhere throws rather than answering an empty diff")
    func missingBaseThrows() async throws {
        let repo = try await TempRepo()
        defer { repo.cleanUp() }

        await #expect(throws: (any Error).self) {
            try await Git.baseline("no-such-branch", in: repo.path)
        }
    }

    @Test("a commit is its own ancestor, and an unrelated one is not")
    func ancestry() async throws {
        let repo = try await TempRepo()
        defer { repo.cleanUp() }

        let first = try await Git.headSHA(of: repo.path)
        try repo.write("second.txt", "second\n")
        try await commitAll(repo, "second")
        let second = try await Git.headSHA(of: repo.path)

        #expect(await Git.isAncestor(first, of: second, in: repo.path))
        #expect(await Git.isAncestor(second, of: second, in: repo.path))
        #expect(await Git.isAncestor(second, of: first, in: repo.path) == false)
        #expect(await Git.isAncestor("no-such-ref", of: second, in: repo.path) == false)
    }
}
