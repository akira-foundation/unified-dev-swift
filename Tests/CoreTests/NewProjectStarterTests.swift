import Testing
import Foundation
@testable import Core

@Suite("Starting a project from nothing", .tags(.git), .scratchDirectory)
struct NewProjectStarterTests {
    private func hasIdentity() async -> Bool {
        await RepositoryStarter.identityProblem(at: NSTemporaryDirectory()) == nil
    }

    private func scratch() -> (location: String, name: String) {
        (TestScratch.unique("unifieddev-new"), "sparkline")
    }

    private func inspect(_ location: String, _ name: String) -> NewProjectFacts {
        NewProjectStarter.inspect(
            name: name,
            location: location,
            home: NSHomeDirectory(),
            workspacesRoot: TestScratch.path("workspaces")
        )
    }

    @Test("a path with nothing at it, under a location that is not there either, is created")
    func createsBoth() {
        let (location, name) = scratch()
        let facts = inspect(location, name)
        #expect(facts.locationExists == false)
        #expect(facts.targetExists == false)
        #expect(NewProjectVerdict.of(facts) == .create(makesLocation: true))
    }

    @Test("an empty folder that is already there is adopted, and a stray .DS_Store is not content")
    func adoptsAnEmptyFolder() throws {
        let (location, name) = scratch()
        let target = (location as NSString).appendingPathComponent(name)
        try FileManager.default.createDirectory(atPath: target, withIntermediateDirectories: true)
        #expect(NewProjectVerdict.of(inspect(location, name)) == .adopt)

        try "".write(
            toFile: (target as NSString).appendingPathComponent(".DS_Store"),
            atomically: true, encoding: .utf8
        )
        #expect(NewProjectVerdict.of(inspect(location, name)) == .adopt)
    }

    @Test("a location inside an existing repository is refused rather than nested")
    func refusesNesting() async throws {
        let repo = try await TempRepo()
        defer { repo.cleanUp() }
        let facts = inspect((repo.path as NSString).appendingPathComponent("sub"), "sparkline")
        guard case .refuse(.insideRepository) = NewProjectVerdict.of(facts) else {
            Issue.record("a folder inside \(repo.path) was not refused")
            return
        }
    }

    @Test("a project made from nothing can have a workspace cut from it straight away")
    func createsAProjectAWorktreeCanStartFrom() async throws {
        guard await hasIdentity() else { return }
        let (location, name) = scratch()
        let target = (location as NSString).appendingPathComponent(name)

        let seen = StepRecorder()
        let creation = try await NewProjectStarter.create(at: target) { step in
            seen.append(step)
        }

        #expect(creation.folderWasCreated)
        #expect(creation.branch == "main")
        #expect(seen.steps == [.initialise, .commit])
        #expect(await Git.isRepository(target))
        #expect(await Git.hasCommits(in: target))
        #expect(try await Git.check(["ls-tree", "-r", "--name-only", "HEAD"], in: target).lines.isEmpty)

        #expect(await CheckoutStanding.of(target, branch: creation.branch) == .fine)

        let worktree = TestScratch.unique("worktree")
        try await Git.addWorktree(
            repo: target, path: worktree, branch: "unifieddev/test", base: creation.branch
        )
        #expect(FileManager.default.fileExists(atPath: worktree))
        try await Git.removeWorktree(repo: target, path: worktree, force: true)
    }

    @Test("an empty folder that was already there is used rather than made")
    func adoptsRatherThanMakes() async throws {
        guard await hasIdentity() else { return }
        let (location, name) = scratch()
        let target = (location as NSString).appendingPathComponent(name)
        try FileManager.default.createDirectory(atPath: target, withIntermediateDirectories: true)

        let creation = try await NewProjectStarter.create(at: target)
        #expect(creation.folderWasCreated == false)
        #expect(await Git.hasCommits(in: target))
    }

    @Test("abandoning takes away exactly what Unified Dev made")
    func discardRemovesTheFolderAppMade() async throws {
        let (location, name) = scratch()
        let target = (location as NSString).appendingPathComponent(name)
        try FileManager.default.createDirectory(atPath: target, withIntermediateDirectories: true)
        try await Shell.check("git", ["init", "-q"], cwd: target)

        let left = await NewProjectStarter.discard(at: target, folderWasCreated: true)
        #expect(left.repository == .repositoryRemoved)
        #expect(left.folderRemoved)
        #expect(FileManager.default.fileExists(atPath: target) == false)
        #expect(left.state.contains("nothing is left on disk"))
    }

    @Test("an adopted folder keeps its place, with the git init undone")
    func discardKeepsAnAdoptedFolder() async throws {
        let (location, name) = scratch()
        let target = (location as NSString).appendingPathComponent(name)
        try FileManager.default.createDirectory(atPath: target, withIntermediateDirectories: true)
        try await Shell.check("git", ["init", "-q"], cwd: target)

        let left = await NewProjectStarter.discard(at: target, folderWasCreated: false)
        #expect(left.repository == .repositoryRemoved)
        #expect(left.folderRemoved == false)
        #expect(FileManager.default.fileExists(atPath: target))
        #expect(FileManager.default.fileExists(atPath: (target as NSString).appendingPathComponent(".git")) == false)
    }

    @Test("a project that reached its first commit is left exactly as it is")
    func discardKeepsAProject() async throws {
        guard await hasIdentity() else { return }
        let (location, name) = scratch()
        let target = (location as NSString).appendingPathComponent(name)
        _ = try await NewProjectStarter.create(at: target)

        let left = await NewProjectStarter.discard(at: target, folderWasCreated: true)
        #expect(left.repository == .projectKept)
        #expect(left.folderRemoved == false)
        #expect(left.isUsableProject)
        #expect(FileManager.default.fileExists(atPath: target))
    }

    @Test("a folder that has gained something in the meantime is not removed")
    func discardKeepsAFolderThatIsNoLongerEmpty() async throws {
        let (location, name) = scratch()
        let target = (location as NSString).appendingPathComponent(name)
        try FileManager.default.createDirectory(atPath: target, withIntermediateDirectories: true)
        try "mine".write(
            toFile: (target as NSString).appendingPathComponent("notes.md"),
            atomically: true, encoding: .utf8
        )

        let left = await NewProjectStarter.discard(at: target, folderWasCreated: true)
        #expect(left.folderRemoved == false)
        #expect(FileManager.default.fileExists(atPath: target))
    }

    @Test("a folder that cannot be read is not treated as an empty one")
    func anUnreadableFolderIsNotEmpty() throws {
        let (location, name) = scratch()
        let target = (location as NSString).appendingPathComponent(name)
        try FileManager.default.createDirectory(atPath: target, withIntermediateDirectories: true)
        #expect(NewProjectStarter.isEmpty(target))

        try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: target)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: target) }

        #expect(!NewProjectStarter.isEmpty(target))
        #expect(!NewProjectStarter.isEmpty(target + "-never-made"))
    }
}

private final class StepRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var collected: [RepositoryStartStep] = []

    var steps: [RepositoryStartStep] {
        lock.lock(); defer { lock.unlock() }
        return collected
    }

    func append(_ step: RepositoryStartStep) {
        lock.lock(); defer { lock.unlock() }
        collected.append(step)
    }
}
