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

    @Test("a renamed file's own patch is the rename, not a new file")
    func renamedFile() async throws {
        let repo = try await TempRepo()
        defer { repo.cleanUp() }
        try repo.write("old.txt", "one\ntwo\nthree\nfour\nfive\n")
        try await repo.commit("old")
        try await Shell.check("git", ["checkout", "-q", "-b", "feature"], cwd: repo.path)
        try await Shell.check("git", ["mv", "old.txt", "new.txt"], cwd: repo.path)
        try repo.write("new.txt", "one\ntwo\nTHREE\nfour\nfive\n")
        try await repo.commit("rename")

        let files = try await Git.changedFiles(worktree: repo.path, base: "main")
        let renamed = try #require(files.first { $0.path == "new.txt" })
        let patch = try await Git.patch(worktree: repo.path, base: "main", file: renamed)

        #expect(renamed.change == .renamed)
        #expect(patch.contains("rename from old.txt"))
        #expect(patch.contains("+THREE"))
        #expect(!patch.contains("new file mode"))
    }

    @Test("an untracked repository nested in the worktree does not stop the whole patch")
    func nestedRepository() async throws {
        let repo = try await TempRepo()
        defer { repo.cleanUp() }
        try repo.write("tracked.txt", "a\n")
        try await repo.commit("tracked")
        try repo.write("tracked.txt", "b\n")
        let nested = (repo.path as NSString).appendingPathComponent("vendor")
        try FileManager.default.createDirectory(atPath: nested, withIntermediateDirectories: true)
        try await Shell.check("git", ["init", "-q"], cwd: nested)
        try "inner\n".write(toFile: (nested as NSString).appendingPathComponent("inner.txt"), atomically: true, encoding: .utf8)

        let files = try await Git.changedFiles(worktree: repo.path, base: "main")
        let patch = try await Git.patch(worktree: repo.path, base: "main", files: files)

        #expect(files.contains { $0.path.hasPrefix("vendor") })
        #expect(patch.contains("+b"))
    }
}
