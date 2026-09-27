import Foundation
import Testing
@testable import Core

@Suite("Discarding a hunk", .tags(.git, .destructive), .scratchDirectory)
struct GitHunkDiscardTests {
    private static let before = (1...30).map { "line \($0)" }.joined(separator: "\n") + "\n"

    private static let after = before
        .replacingOccurrences(of: "line 2\n", with: "line two\n")
        .replacingOccurrences(of: "line 25\n", with: "line twenty-five\n")

    private func repo(named path: String = "file.txt") async throws -> TempRepo {
        let repo = try await TempRepo()
        try repo.write(path, Self.before)
        try await repo.commit("Before")
        try repo.write(path, Self.after)
        return repo
    }

    private func hunks(_ repo: TempRepo, _ file: ChangedFile, scope: DiffScope = .all) async throws -> [DiffHunk] {
        let patch = try await Git.patch(worktree: repo.path, base: "main", file: file, scope: scope)
        return try #require(DiffParser.parse(patch).first).hunks
    }

    private func staged(_ repo: TempRepo, _ path: String) async throws -> String {
        try await Shell.check("git", ["show", ":\(path)"], cwd: repo.path).stdout
    }

    @Test("one hunk goes and the other stays")
    func discardsOnlyThePressedHunk() async throws {
        let repo = try await repo()
        defer { repo.cleanUp() }
        let file = ChangedFile(path: "file.txt", change: .modified)
        let shown = try await hunks(repo, file)
        #expect(shown.count == 2)

        try await Git.discardHunk(shown[0], of: file, worktree: repo.path, base: "main", scope: .all)

        let text = try #require(repo.read("file.txt"))
        #expect(text.contains("line 2\n"))
        #expect(text.contains("line twenty-five\n"))
    }

    @Test("a staged hunk leaves the index as well as the worktree")
    func stagedHunkLeavesBoth() async throws {
        let repo = try await repo()
        defer { repo.cleanUp() }
        try await Shell.check("git", ["add", "file.txt"], cwd: repo.path)
        let file = ChangedFile(path: "file.txt", change: .modified)
        let shown = try await hunks(repo, file, scope: .uncommitted)

        try await Git.discardHunk(shown[1], of: file, worktree: repo.path, base: "main", scope: .uncommitted)

        let index = try await staged(repo, "file.txt")
        let text = try #require(repo.read("file.txt"))
        #expect(index.contains("line 25\n"))
        #expect(index.contains("line two\n"))
        #expect(text.contains("line 25\n"))
        #expect(text.contains("line two\n"))
    }

    @Test("an unstaged hunk leaves the index alone")
    func unstagedHunkLeavesTheIndex() async throws {
        let repo = try await repo()
        defer { repo.cleanUp() }
        let file = ChangedFile(path: "file.txt", change: .modified)
        let shown = try await hunks(repo, file, scope: .uncommitted)

        try await Git.discardHunk(shown[0], of: file, worktree: repo.path, base: "main", scope: .uncommitted)

        let index = try await staged(repo, "file.txt")
        #expect(repo.read("file.txt")?.contains("line 2\n") == true)
        #expect(index == Self.before)
    }

    @Test("an index holding another version of the hunk is left as it is")
    func differentIndexIsLeftAlone() async throws {
        let repo = try await repo()
        defer { repo.cleanUp() }
        try await Shell.check("git", ["add", "file.txt"], cwd: repo.path)
        try repo.write("file.txt", Self.after.replacingOccurrences(of: "line two\n", with: "line zwei\n"))
        let file = ChangedFile(path: "file.txt", change: .modified)
        let shown = try await hunks(repo, file, scope: .uncommitted)

        try await Git.discardHunk(shown[0], of: file, worktree: repo.path, base: "main", scope: .uncommitted)

        let index = try await staged(repo, "file.txt")
        #expect(repo.read("file.txt")?.contains("line 2\n") == true)
        #expect(index.contains("line two\n"))
    }

    @Test("a hunk committed on the branch is discarded from the worktree and the index")
    func committedHunk() async throws {
        let repo = try await TempRepo()
        defer { repo.cleanUp() }
        try repo.write("file.txt", Self.before)
        try await repo.commit("Before")
        try await Shell.check("git", ["checkout", "-q", "-b", "feature"], cwd: repo.path)
        try repo.write("file.txt", Self.after)
        try await repo.commit("After")
        let file = ChangedFile(path: "file.txt", change: .modified)
        let shown = try await hunks(repo, file)

        try await Git.discardHunk(shown[0], of: file, worktree: repo.path, base: "main", scope: .all)

        let index = try await staged(repo, "file.txt")
        let text = try #require(repo.read("file.txt"))
        #expect(text.contains("line 2\n"))
        #expect(text.contains("line twenty-five\n"))
        #expect(index.contains("line 2\n"))
        #expect(index.contains("line twenty-five\n"))
    }

    @Test("a file changed under the diff refuses and writes nothing")
    func staleHunkRefuses() async throws {
        let repo = try await repo()
        defer { repo.cleanUp() }
        let file = ChangedFile(path: "file.txt", change: .modified)
        let shown = try await hunks(repo, file)
        let moved = Self.after.replacingOccurrences(of: "line two\n", with: "line deux\n")
        try repo.write("file.txt", moved)

        await #expect(throws: HunkDiscardRefusal.changed) {
            try await Git.discardHunk(shown[0], of: file, worktree: repo.path, base: "main", scope: .all)
        }
        #expect(repo.read("file.txt") == moved)
    }

    @Test("a file that is all one change is refused before git is asked")
    func addedFileIsNotOffered() async throws {
        let repo = try await repo()
        defer { repo.cleanUp() }
        let modified = ChangedFile(path: "file.txt", change: .modified)
        let shown = try await hunks(repo, modified)
        let added = ChangedFile(path: "file.txt", change: .added)

        await #expect(throws: HunkDiscardRefusal.notOffered) {
            try await Git.discardHunk(shown[0], of: added, worktree: repo.path, base: "main", scope: .all)
        }
        #expect(repo.read("file.txt") == Self.after)
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
        let text = try #require(repo.read("new \u{e9}.txt"))
        #expect(text.contains("line 2\n"))
        #expect(text.contains("line twenty-five\n"))
    }

    @Test("a path git has to quote is discarded like any other")
    func quotedPath() async throws {
        let name = "say \"hi\".txt"
        let repo = try await repo(named: name)
        defer { repo.cleanUp() }
        let file = ChangedFile(path: name, change: .modified)
        let shown = try await hunks(repo, file)

        try await Git.discardHunk(shown[1], of: file, worktree: repo.path, base: "main", scope: .all)

        let text = try #require(repo.read(name))
        #expect(text.contains("line two\n"))
        #expect(text.contains("line 25\n"))
    }
}
