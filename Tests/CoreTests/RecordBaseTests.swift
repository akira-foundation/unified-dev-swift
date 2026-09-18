import Foundation
import Testing
@testable import Core

@Suite("Recording the base of a new branch", .tags(.git), .scratchDirectory)
struct RecordBaseTests {
    @Test("a base whose name starts with a dash is stored, not read as an option")
    func dashedBaseIsAValue() async throws {
        let repo = try await TempRepo()
        defer { repo.cleanUp() }
        let context = GitRepositoryContext(
            baseBranch: "-fsomewhere",
            baseRemote: "-x",
            publishBranch: "main",
            publishRemote: nil,
            baseRemoteURL: nil,
            publishRemoteURL: nil
        )

        try await Git.recordBase(context, for: "main", in: repo.path)

        let base = try await Shell.check("git", ["config", "--get", "branch.main.gh-merge-base"], cwd: repo.path)
        let remote = try await Shell.check(
            "git", ["config", "--get", "branch.main.unifieddev-base-remote"], cwd: repo.path
        )
        #expect(base.trimmed == "-fsomewhere")
        #expect(remote.trimmed == "-x")
    }
}
