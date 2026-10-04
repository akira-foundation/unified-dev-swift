import Foundation
import Testing
@testable import Core

@Suite("The write path's own refusals", .tags(.git, .destructive), .scratchDirectory)
struct HunkDiscardWritePathTests {
    @Test("a file that offers no hunk is refused before git is asked anything at all")
    func refusedBeforeGitIsAsked() async throws {
        let folder = TestScratch.unique("unifieddev-not-a-repo")
        try FileManager.default.createDirectory(atPath: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(atPath: folder) }
        #expect(!(await Git.isRepository(folder)))
        let hunk = DiffHunk(oldStart: 1, oldCount: 1, newStart: 1, newCount: 1, lines: [
            DiffLine(kind: .deletion, text: "line 1"),
            DiffLine(kind: .addition, text: "line one"),
        ])

        await #expect(throws: HunkDiscardRefusal.notOffered) {
            try await Git.discardHunk(
                hunk, of: ChangedFile(path: "a.txt", change: .added), worktree: folder,
                base: "main", scope: .all
            )
        }
    }

    @Test("a submodule bump is refused by the write path, not only by the control that offers it")
    func submoduleBumpIsRefusedWhereItWouldBeWritten() async throws {
        let inner = try await TempRepo()
        defer { inner.cleanUp() }
        try inner.write("a.txt", "one\n")
        try await inner.commit("One")
        let first = try await Git.headSHA(of: inner.path)
        try inner.write("a.txt", "two\n")
        try await inner.commit("Two")

        let outer = try await TempRepo()
        defer { outer.cleanUp() }
        try outer.write("keep.txt", "keep\n")
        try await outer.commit("Keep")
        try await Shell.check(
            "git", ["-c", "protocol.file.allow=always", "submodule", "add", "-q", inner.path, "sub"],
            cwd: outer.path
        )
        try await Shell.check("git", ["commit", "-q", "-m", "Add the submodule"], cwd: outer.path)
        let sub = (outer.path as NSString).appendingPathComponent("sub")
        try await Shell.check("git", ["checkout", "-q", first], cwd: sub)

        let file = ChangedFile(path: "sub", change: .modified)
        let drawn = try await Git.patch(worktree: outer.path, base: "main", file: file)
        let diff = try #require(DiffParser.parse(drawn).first)
        #expect(diff.newMode == HunkDiscard.gitlinkMode)
        let bump = try #require(diff.hunks.first)

        await #expect(throws: HunkDiscardRefusal.notOffered) {
            try await Git.discardHunk(bump, of: file, worktree: outer.path, base: "main", scope: .all)
        }
        #expect(try await Git.headSHA(of: sub) == first)
    }

    @Test("an untracked file handed to the tracked revert is refused in our words, not in git's")
    func trackedRevertRefusesAnUntrackedFile() async throws {
        let repo = try await TempRepo()
        defer { repo.cleanUp() }
        try repo.write("notes.txt", "kept\n")
        try await repo.commit("Notes")
        try repo.write("stray.txt", "draft\n")

        let refused = await #expect(throws: ShellError.self) {
            try await Git.revertTrackedFile(
                ChangedFile(path: "stray.txt", change: .untracked), worktree: repo.path, base: "main"
            )
        }

        #expect(refused?.stderr == "Untracked files must be moved to the Trash.")
        #expect(repo.read("stray.txt") == "draft\n")
    }
}
