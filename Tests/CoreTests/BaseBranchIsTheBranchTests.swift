import Foundation
import Testing
@testable import Core

@Suite("A base branch that is the branch itself", .tags(.git), .scratchDirectory)
struct BaseBranchIsTheBranchTests {
    @Test("a branch measured against itself is not merged, so its commits still count as losses")
    func measuringAgainstItselfIsNotMerged() async throws {
        let repo = try await TempRepo()
        defer { repo.cleanUp() }

        try repo.write("pier.txt", "wood\n")
        try await repo.commit("Lay the pier")

        let report = try await Git.safetyReport(
            worktree: repo.path, branch: "main", base: "main", repo: repo.path
        )
        #expect(report.hasUncommittedChanges == false)
        #expect(report.unpushedCommits > 0)
        #expect(report.isBranchMerged == false)
        #expect(report.isSafeToDiscard == false)
        #expect(report.losses.contains { $0.contains("exist on no other branch, tag or remote") })
    }

    @Test("a base that really is another branch is still measured")
    func anotherBaseIsStillMeasured() async throws {
        let repo = try await TempRepo()
        defer { repo.cleanUp() }

        try await Shell.check("git", ["checkout", "-q", "-b", "pier"], cwd: repo.path)
        try repo.write("pier.txt", "wood\n")
        try await repo.commit("Lay the pier")
        try await Shell.check("git", ["checkout", "-q", "main"], cwd: repo.path)
        try await Shell.check("git", ["merge", "--no-edit", "-q", "pier"], cwd: repo.path)

        let report = try await Git.safetyReport(
            worktree: repo.path, branch: "pier", base: "main", repo: repo.path
        )
        #expect(report.isBranchMerged)
        #expect(report.isSafeToDiscard)
    }
}
