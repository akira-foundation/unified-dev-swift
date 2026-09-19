import Foundation
import Testing
@testable import Core

@Suite("Adding a suggestion's folder as a project", .tags(.git, .subprocess, .persistence), .scratchDirectory)
struct WorkSuggestionFolderTests {
    private func manager(_ label: String) throws -> WorkspaceManager {
        WorkspaceManager(
            store: try makeTestStore(label),
            workspacesRoot: URL(fileURLWithPath: TestScratch.unique("workspaces"), isDirectory: true)
        )
    }

    @Test("a repository on disk passes the Add Project check and becomes a project")
    func addsARepository() async throws {
        let repo = try await TempRepo()
        defer { repo.cleanUp() }
        let manager = try manager("folder-repo")

        let admitted = await WorkSuggestionLaunch.admit(repo.path, with: manager)
        let project = try admitted.get()
        let projects = try await manager.store.repos()

        #expect(FolderPath.resolved(project.path) == FolderPath.resolved(repo.path))
        #expect(projects.map(\.id) == [project.id])
    }

    @Test("a folder that is not a repository is refused, and Unified Dev does not make one")
    func refusesAPlainFolder() async throws {
        let folder = TestScratch.unique("plain-folder")
        try FileManager.default.createDirectory(atPath: folder, withIntermediateDirectories: true)
        try "notes\n".write(toFile: folder + "/notes.txt", atomically: true, encoding: .utf8)
        let manager = try manager("folder-plain")

        let admitted = await WorkSuggestionLaunch.admit(folder, with: manager)
        let projects = try await manager.store.repos()

        guard case .failure(let refusal) = admitted else { Issue.record("\(admitted)"); return }
        #expect(refusal.sentence.contains("not a git repository"))
        #expect(!FileManager.default.fileExists(atPath: folder + "/.git"))
        #expect(projects.isEmpty)
    }

    @Test("a path with nothing there is refused with the Add Project check's own words")
    func refusesNothing() async throws {
        let missing = TestScratch.unique("nothing-here")
        let manager = try manager("folder-missing")

        let admitted = await WorkSuggestionLaunch.admit(missing, with: manager)

        guard case .failure(let refusal) = admitted else { Issue.record("\(admitted)"); return }
        #expect(refusal.sentence == FolderRefusal.nothingThere(missing).sentence)
    }
}
