import Foundation
import Testing
@testable import Core

@Suite("Discarding a hunk from an awkward path", .tags(.git, .destructive), .scratchDirectory)
struct GitHunkDiscardPathTests {
    private static let before = (1...30).map { "line \($0)" }.joined(separator: "\n") + "\n"

    private static let after = before
        .replacingOccurrences(of: "line 2\n", with: "line two\n")
        .replacingOccurrences(of: "line 25\n", with: "line twenty-five\n")

    private static let firstDiscarded = after.replacingOccurrences(of: "line two\n", with: "line 2\n")

    private static let lastDiscarded =
        after.replacingOccurrences(of: "line twenty-five\n", with: "line 25\n")

    private func repo(named path: String) async throws -> TempRepo {
        let repo = try await TempRepo()
        try repo.write(path, Self.before)
        try await repo.commit("Before")
        try repo.write(path, Self.after)
        return repo
    }

    private func hunks(_ repo: TempRepo, _ file: ChangedFile) async throws -> [DiffHunk] {
        let patch = try await Git.patch(worktree: repo.path, base: "main", file: file, scope: .all)
        return try #require(DiffParser.parse(patch).first).hunks
    }

    private func staged(_ repo: TempRepo, _ path: String) async throws -> String {
        try await Shell.check("git", ["show", ":\(path)"], cwd: repo.path).stdout
    }

    @Test("a renamed file with an accented name keeps its new name")
    func renamedFileStaysRenamed() async throws {
        let repo = try await repo(named: "old name.txt")
        defer { repo.cleanUp() }
        try await Shell.check("git", ["mv", "old name.txt", "new \u{e9}.txt"], cwd: repo.path)
        let file = ChangedFile(path: "new \u{e9}.txt", oldPath: "old name.txt", change: .renamed)
        let shown = try await hunks(repo, file)
        #expect(shown.count == 2)

        try await Git.discardHunk(shown[0], of: file, worktree: repo.path, base: "main", scope: .all)

        #expect(!repo.exists("old name.txt"))
        #expect(repo.exists("new \u{e9}.txt"))
        #expect(repo.read("new \u{e9}.txt") == Self.firstDiscarded)
        #expect(try await staged(repo, "new \u{e9}.txt") == Self.before)
    }

    @Test("a path git has to quote is discarded like any other")
    func quotedPath() async throws {
        let name = "say \"hi\".txt"
        let repo = try await repo(named: name)
        defer { repo.cleanUp() }
        let file = ChangedFile(path: name, change: .modified)
        let shown = try await hunks(repo, file)

        try await Git.discardHunk(shown[1], of: file, worktree: repo.path, base: "main", scope: .all)

        #expect(repo.read(name) == Self.lastDiscarded)
    }

    @Test("a path whose space hides a b/ is discarded, and the file of that name is untouched")
    func spacedPathLeavesItsDecoy() async throws {
        let repo = try await TempRepo()
        defer { repo.cleanUp() }
        try repo.write("sneaky b/decoy.txt", Self.before)
        try repo.write("decoy.txt", Self.before)
        try await repo.commit("Before")
        try repo.write("sneaky b/decoy.txt", Self.after)
        try repo.write("decoy.txt", Self.after)
        let file = ChangedFile(path: "sneaky b/decoy.txt", change: .modified)
        let shown = try await hunks(repo, file)

        try await Git.discardHunk(shown[1], of: file, worktree: repo.path, base: "main", scope: .all)

        #expect(repo.read("sneaky b/decoy.txt") == Self.lastDiscarded)
        #expect(repo.read("decoy.txt") == Self.after)
    }

    @Test("a quoted path with a space and quotes in it leaves the file of the same name alone")
    func quotedPathLeavesItsDecoy() async throws {
        let name = "sneaky b/say \"hi\".txt"
        let repo = try await TempRepo()
        defer { repo.cleanUp() }
        try repo.write(name, Self.before)
        try repo.write("say \"hi\".txt", Self.before)
        try await repo.commit("Before")
        try repo.write(name, Self.after)
        try repo.write("say \"hi\".txt", Self.after)
        let file = ChangedFile(path: name, change: .modified)
        let shown = try await hunks(repo, file)

        try await Git.discardHunk(shown[0], of: file, worktree: repo.path, base: "main", scope: .all)

        #expect(repo.read(name) == Self.firstDiscarded)
        #expect(repo.read("say \"hi\".txt") == Self.after)
    }
}
