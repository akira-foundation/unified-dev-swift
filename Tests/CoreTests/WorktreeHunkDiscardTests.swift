import Foundation
import Testing
@testable import Core

@Suite("Discarding a hunk in a workspace", .tags(.git, .destructive), .scratchDirectory)
struct WorktreeHunkDiscardTests {
    private static let before = (1...30).map { "line \($0)" }.joined(separator: "\n") + "\n"
    private static let after = before.replacingOccurrences(of: "line 2\n", with: "line two\n")

    private func workspace(at path: String) -> Workspace {
        Workspace(repoID: .new(), name: "Hunk", branch: "main", path: path, baseBranch: "main")
    }

    private func setUp() async throws -> (TempRepo, ChangedFile, DiffHunk) {
        let repo = try await TempRepo()
        try repo.write("file.txt", Self.before)
        try await repo.commit("Before")
        try repo.write("file.txt", Self.after)
        let file = ChangedFile(path: "file.txt", change: .modified)
        let patch = try await Git.patch(worktree: repo.path, base: "main", file: file)
        let hunk = try #require(DiffParser.parse(patch).first?.hunks.first)
        return (repo, file, hunk)
    }

    @Test("a discarded hunk is reverted and asks for a refresh")
    func discarded() async throws {
        let (repo, file, hunk) = try await setUp()
        defer { repo.cleanUp() }

        let outcome = await WorktreeHunkDiscard.discard(
            hunk, of: file, in: workspace(at: repo.path), scope: .all, refusal: nil
        )

        #expect(outcome == .reverted)
        #expect(outcome.refreshesChanges)
        #expect(repo.read("file.txt") == Self.before)
    }

    @Test("a refusal is passed through and git is never asked")
    func refusedBeforeGit() async throws {
        let (repo, file, hunk) = try await setUp()
        defer { repo.cleanUp() }

        let outcome = await WorktreeHunkDiscard.discard(
            hunk, of: file, in: workspace(at: repo.path), scope: .all,
            refusal: FileBarControls.revertWhileAgentWorks
        )

        #expect(outcome == .refused(FileBarControls.revertWhileAgentWorks))
        #expect(!outcome.refreshesChanges)
        #expect(repo.read("file.txt") == Self.after)
    }

    @Test("a hunk that moved under the diff is refused with the reason, and the file is left alone")
    func changedUnderTheDiff() async throws {
        let (repo, file, hunk) = try await setUp()
        defer { repo.cleanUp() }
        let moved = Self.after.replacingOccurrences(of: "line two\n", with: "line deux\n")
        try repo.write("file.txt", moved)

        let outcome = await WorktreeHunkDiscard.discard(
            hunk, of: file, in: workspace(at: repo.path), scope: .all, refusal: nil
        )

        #expect(outcome == .refused(HunkDiscardRefusal.changed.errorDescription ?? ""))
        #expect(repo.read("file.txt") == moved)
    }
}
