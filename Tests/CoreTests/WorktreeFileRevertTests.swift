import Foundation
import Testing
@testable import Core

@Suite("Reverting one file in a worktree", .tags(.git), .scratchDirectory)
struct WorktreeFileRevertTests {
    private func workspace(at path: String) -> Workspace {
        Workspace(repoID: .new(), name: "Revert", branch: "main", path: path, baseBranch: "main")
    }

    @Test("a tracked file goes back to the base, and only then may the draft go")
    func revertedFileLetsTheDraftGo() async throws {
        let repo = try await TempRepo()
        defer { repo.cleanUp() }
        try repo.write("docs/pier.txt", "wood\n")
        try await repo.commit("Pier")
        try repo.write("docs/pier.txt", "stone\n")

        let outcome = await WorktreeFileRevert.revert(
            ChangedFile(path: "docs/pier.txt", change: .modified), in: workspace(at: repo.path),
            refusal: nil
        )

        #expect(outcome == .reverted)
        #expect(outcome.discardsDraft)
        #expect(outcome.refreshesChanges)
        #expect(repo.read("docs/pier.txt") == "wood\n")
    }

    @Test("a revert git cannot carry out leaves the file alone and keeps the draft")
    func failedRevertKeepsTheDraft() async throws {
        let repo = try await TempRepo()
        let folder = (repo.path as NSString).appendingPathComponent("docs")
        defer {
            try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: folder)
            repo.cleanUp()
        }
        try repo.write("docs/pier.txt", "wood\n")
        try await repo.commit("Pier")
        try repo.write("docs/pier.txt", "stone\n")
        try FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: folder)

        let outcome = await WorktreeFileRevert.revert(
            ChangedFile(path: "docs/pier.txt", change: .modified), in: workspace(at: repo.path),
            refusal: nil
        )

        guard case let .failed(detail) = outcome else {
            Issue.record("expected the revert to fail, got \(outcome)")
            return
        }
        #expect(detail.contains("unable to unlink"))
        #expect(!outcome.discardsDraft)
        #expect(outcome.refreshesChanges)
        #expect(repo.read("docs/pier.txt") == "stone\n")
    }

    @Test("a refused revert touches nothing and keeps the draft")
    func refusedRevertTouchesNothing() async throws {
        let repo = try await TempRepo()
        defer { repo.cleanUp() }
        try repo.write("docs/pier.txt", "wood\n")
        try await repo.commit("Pier")
        try repo.write("docs/pier.txt", "stone\n")

        let outcome = await WorktreeFileRevert.revert(
            ChangedFile(path: "docs/pier.txt", change: .modified), in: workspace(at: repo.path),
            refusal: FileBarControls.revertWhileAgentWorks
        )

        #expect(outcome == .refused(FileBarControls.revertWhileAgentWorks))
        #expect(!outcome.discardsDraft)
        #expect(!outcome.refreshesChanges)
        #expect(repo.read("docs/pier.txt") == "stone\n")
    }

    @Test("an untracked file that cannot go to the Trash is reported and keeps the draft")
    func untrackedFileTheTrashRefuses() async throws {
        let repo = try await TempRepo()
        defer { repo.cleanUp() }

        let outcome = await WorktreeFileRevert.revert(
            ChangedFile(path: "docs/gone.txt", change: .untracked), in: workspace(at: repo.path),
            refusal: nil
        )

        guard case let .failed(detail) = outcome else {
            Issue.record("expected the revert to fail, got \(outcome)")
            return
        }
        #expect(detail.hasPrefix("It could not be moved to the Trash"))
        #expect(!outcome.discardsDraft)
    }
}
