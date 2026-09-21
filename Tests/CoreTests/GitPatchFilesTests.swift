import Foundation
import Testing
@testable import Core

@Suite("Git.patch over every changed file", .tags(.git, .subprocess), .scratchDirectory)
struct GitPatchFilesTests {
    @Test("one patch holds committed, uncommitted and untracked work, and nothing the base did later")
    func wholeBranch() async throws {
        let repo = try await TempRepo()
        defer { repo.cleanUp() }
        try repo.write("shared.txt", "one\ntwo\nthree\n")
        try await repo.commit("shared")
        try await Shell.check("git", ["checkout", "-q", "-b", "later-on-main"], cwd: repo.path)
        try repo.write("main-only.txt", "not this branch's\n")
        try await repo.commit("main moves on")
        try await Shell.check("git", ["checkout", "-q", "main"], cwd: repo.path)
        try await Shell.check("git", ["checkout", "-q", "-b", "feature"], cwd: repo.path)
        try await Shell.check("git", ["branch", "-f", "main", "later-on-main"], cwd: repo.path)
        try repo.write("committed.txt", "a\nb\n")
        try await repo.commit("feature work")
        try repo.write("shared.txt", "one\nTWO\nthree\n")
        try repo.write("untracked.txt", "fresh\n")

        let files = try await Git.changedFiles(worktree: repo.path, base: "main")
        let patch = try await Git.patch(worktree: repo.path, base: "main", files: files)

        for fragment in ["b/committed.txt", "+TWO", "-two", "b/untracked.txt", "+fresh"] {
            #expect(patch.contains(fragment), "missing \(fragment)")
        }
        #expect(!patch.contains("main-only.txt"))
    }

    @Test("with nothing changed the patch is empty")
    func nothingChanged() async throws {
        let repo = try await TempRepo()
        defer { repo.cleanUp() }

        let files = try await Git.changedFiles(worktree: repo.path, base: "main")
        let patch = try await Git.patch(worktree: repo.path, base: "main", files: files)

        #expect(files.isEmpty)
        #expect(patch.isEmpty)
    }
}
