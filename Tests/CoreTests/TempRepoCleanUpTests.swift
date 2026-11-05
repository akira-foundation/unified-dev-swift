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
        let root = URL(fileURLWithPath: TestScratch.unique("managed-root"), isDirectory: true)
        let folder = root
            .appendingPathComponent(ProfileID.initial.rawValue, isDirectory: true)
            .appendingPathComponent(name, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        TempRepo(existing: "/nowhere/\(name)").removeManagedFolders(under: root)

        #expect(FileManager.default.fileExists(atPath: folder.path))
    }

    @Test("leaves a fixed name alone, so a repository named like a profile cannot take its folder")
    func leavesFixedNameAlone() throws {
        let root = URL(fileURLWithPath: TestScratch.unique("managed-root"), isDirectory: true)
        let profileFolder = root.appendingPathComponent("unified", isDirectory: true)
        let projectFolder = root.appendingPathComponent("akira/unified", isDirectory: true)
        for folder in [profileFolder, projectFolder] {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        }

        TempRepo(existing: TestScratch.path("unified")).removeManagedFolders(under: root)

        #expect(FileManager.default.fileExists(atPath: profileFolder.path))
        #expect(FileManager.default.fileExists(atPath: projectFolder.path))
    }

    @Test("removes a name ending in a UUID at the root and under each profile folder")
    func removesUniqueName() throws {
        let path = TestScratch.unique("unifieddev-git")
        let name = (path as NSString).lastPathComponent
        let root = URL(fileURLWithPath: TestScratch.unique("managed-root"), isDirectory: true)
        let atRoot = root.appendingPathComponent(name, isDirectory: true)
        let underProfile = root.appendingPathComponent("akira/\(name)", isDirectory: true)
        for folder in [atRoot, underProfile] {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        }

        TempRepo(existing: path).removeManagedFolders(under: root)

        #expect(!FileManager.default.fileExists(atPath: atRoot.path))
        #expect(!FileManager.default.fileExists(atPath: underProfile.path))
    }
}
