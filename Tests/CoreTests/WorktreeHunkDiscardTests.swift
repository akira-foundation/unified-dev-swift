import Foundation
import Testing
@testable import Core

@Suite("Discarding a hunk in a workspace", .tags(.git, .destructive), .scratchDirectory)
struct WorktreeHunkDiscardTests {
    private static let before = (1...30).map { "line \($0)" }.joined(separator: "\n") + "\n"

    private static let after = before
        .replacingOccurrences(of: "line 2\n", with: "line two\n")
        .replacingOccurrences(of: "line 25\n", with: "line twenty-five\n")

    private static let firstDiscarded = after.replacingOccurrences(of: "line two\n", with: "line 2\n")

    private func workspace(at path: String) -> Workspace {
        Workspace(repoID: .new(), name: "Hunk", branch: "main", path: path, baseBranch: "main")
    }

    private func setUp(at relative: String = "file.txt") async throws -> (TempRepo, ChangedFile, [DiffHunk]) {
        let repo = try await TempRepo()
        try repo.write(relative, Self.before)
        try await repo.commit("Before")
        try repo.write(relative, Self.after)
        let file = ChangedFile(path: relative, change: .modified)
        let patch = try await Git.patch(worktree: repo.path, base: "main", file: file)
        let hunks = try #require(DiffParser.parse(patch).first).hunks
        #expect(hunks.count == 2)
        return (repo, file, hunks)
    }

    @Test("the pressed hunk goes, the other one stays, and a refresh is asked for")
    func discarded() async throws {
        let (repo, file, hunks) = try await setUp()
        defer { repo.cleanUp() }

        let outcome = await WorktreeHunkDiscard.discard(
            hunks[0], of: file, in: workspace(at: repo.path), scope: .all, refusal: nil
        )

        #expect(outcome == .reverted)
        #expect(outcome.refreshesChanges)
        #expect(repo.read("file.txt") == Self.firstDiscarded)
    }

    @Test("a refusal is passed through and git is never asked")
    func refusedBeforeGit() async throws {
        let (repo, file, hunks) = try await setUp()
        defer { repo.cleanUp() }

        let outcome = await WorktreeHunkDiscard.discard(
            hunks[0], of: file, in: workspace(at: repo.path), scope: .all,
            refusal: FileBarControls.revertWhileAgentWorks
        )

        #expect(outcome == .refused(FileBarControls.revertWhileAgentWorks))
        #expect(!outcome.refreshesChanges)
        #expect(repo.read("file.txt") == Self.after)
    }

    @Test("a hunk that moved under the diff is refused with the reason, and the file is left alone")
    func changedUnderTheDiff() async throws {
        let (repo, file, hunks) = try await setUp()
        defer { repo.cleanUp() }
        let moved = Self.after.replacingOccurrences(of: "line two\n", with: "line deux\n")
        try repo.write("file.txt", moved)

        let outcome = await WorktreeHunkDiscard.discard(
            hunks[0], of: file, in: workspace(at: repo.path), scope: .all, refusal: nil
        )

        #expect(outcome == .refused(HunkDiscardRefusal.changed.errorDescription ?? ""))
        #expect(repo.read("file.txt") == moved)
    }

    @Test("a hunk folded away by ignoring whitespace is refused rather than guessed at")
    func foldedHunkIsRefused() async throws {
        let repo = try await TempRepo()
        defer { repo.cleanUp() }
        try repo.write("file.txt", "alpha\n    indented\nmiddle\nomega\ntail\n")
        try await repo.commit("Before")
        let reindented = "alpha\n\tindented\nmiddle\nOMEGA\ntail\n"
        try repo.write("file.txt", reindented)
        let file = ChangedFile(path: "file.txt", change: .modified)
        let patch = try await Git.patch(worktree: repo.path, base: "main", file: file)
        let raw = try #require(DiffParser.parse(patch).first)
        let folded = raw.ignoringWhitespace()
        let hunk = try #require(folded.hunks.first)
        let raws = try #require(raw.hunks.first)
        #expect(hunk.lines.map(\.kind) != raws.lines.map(\.kind))

        let outcome = await WorktreeHunkDiscard.discard(
            hunk, of: file, in: workspace(at: repo.path), scope: .all, refusal: nil
        )

        #expect(outcome == .refused(HunkDiscardRefusal.changed.errorDescription ?? ""))
        #expect(repo.read("file.txt") == reindented)
    }

    @Test("a write git cannot carry out says so in git's own words and leaves the file alone")
    func failedWriteCarriesGit() async throws {
        let (repo, file, hunks) = try await setUp(at: "docs/file.txt")
        let folder = (repo.path as NSString).appendingPathComponent("docs")
        defer {
            try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: folder)
            repo.cleanUp()
        }
        try FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: folder)

        let outcome = await WorktreeHunkDiscard.discard(
            hunks[0], of: file, in: workspace(at: repo.path), scope: .all, refusal: nil
        )

        guard case let .failed(detail) = outcome else {
            Issue.record("expected the discard to fail, got \(outcome)")
            return
        }
        #expect(!detail.isEmpty)
        #expect(detail.lowercased().contains("docs/file.txt"))
        #expect(repo.read("docs/file.txt") == Self.after)
    }
}
