import Foundation
import Testing
@testable import Core

@Suite("A test repository's cleanup", .tags(.git, .subprocess), .scratchDirectory)
struct TempRepoCleanUpTests {
    @Test("removes the folder its worktrees left under the profile folder of the real root")
    func removesProjectFolderUnderProfile() async throws {
        let repo = try await TempRepo()
        let store = try makeTestStore("cleanup")
        let manager = WorkspaceManager(store: store)
        let project = try await manager.addRepository(at: repo.path, profileID: .initial)
        let workspace = try await manager.createWorkspace(repo: project, prompt: "Some work")
        let projectFolder = (workspace.path as NSString).deletingLastPathComponent
        #expect(FileManager.default.fileExists(atPath: projectFolder))

        repo.cleanUp()

        #expect(!FileManager.default.fileExists(atPath: projectFolder))
    }

    @Test("leaves a folder of the same name alone when the repository is not one of the test's own")
    func leavesRealFoldersAlone() throws {
        let name = "cleanup-keeps-\(UUID().uuidString)"
        let folder = WorkspaceManager.workspacesRoot
            .appendingPathComponent(ProfileID.initial.rawValue, isDirectory: true)
            .appendingPathComponent(name, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }

        TempRepo(existing: "/nowhere/\(name)").cleanUp()

        #expect(FileManager.default.fileExists(atPath: folder.path))
    }
}
