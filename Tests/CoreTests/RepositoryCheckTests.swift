import Foundation
import Testing
@testable import Core

@Suite("What git said about the folder being started", .scratchDirectory)
struct RepositoryCheckTests {
    private let problem = GitRepositoryProblem.unsafeOwnership(path: "/Users/tester/dev/thing")

    private func typed(_ path: String) -> NewProjectFacts {
        NewProjectFacts(
            name: (path as NSString).lastPathComponent,
            location: (path as NSString).deletingLastPathComponent,
            path: path,
            locationExists: true,
            targetExists: true,
            targetIsDirectory: true,
            targetIsRepository: true,
            nearestExistingAncestor: (path as NSString).deletingLastPathComponent,
            homeDirectory: "/Users/tester",
            workspacesRoot: "/Users/tester/unifieddev/workspaces"
        )
    }

    @Test("git's answer about the typed folder decides the verdict")
    func samePathRefuses() {
        let check = RepositoryCheck(path: "/Users/tester/dev/thing", problem: problem)
        let verdict = ProjectTargetVerdict.of(check.applied(to: typed("/Users/tester/dev/thing")))
        #expect(verdict == .refuse(.folder(.gitCannotRead(problem))))
    }

    @Test("an answer about another folder is not applied to the one typed now")
    func otherPathIsIgnored() {
        let check = RepositoryCheck(path: "/Users/tester/dev/other", problem: problem)
        let verdict = ProjectTargetVerdict.of(check.applied(to: typed("/Users/tester/dev/thing")))
        #expect(verdict == .add(root: "/Users/tester/dev/thing"))
    }

    @Test("a .git that points nowhere is a problem, and a real repository is not")
    func askingGit() async throws {
        let broken = TestScratch.unique("broken-git")
        try FileManager.default.createDirectory(atPath: broken, withIntermediateDirectories: true)
        try "gitdir: /nonexistent/broken\n".write(
            toFile: (broken as NSString).appendingPathComponent(".git"), atomically: true, encoding: .utf8
        )
        let refused = await RepositoryCheck.asking(gitAbout: broken)
        #expect(refused.path == broken)
        #expect(refused.problem != nil)

        let repository = try await TempRepo()
        let accepted = await RepositoryCheck.asking(gitAbout: repository.path)
        #expect(accepted.problem == nil)
    }
}
