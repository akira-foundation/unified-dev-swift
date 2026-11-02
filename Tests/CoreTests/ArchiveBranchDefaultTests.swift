import Foundation
import Testing
@testable import Core

@Suite("Deleting the branch on archive", .tags(.git, .destructive), .scratchDirectory)
struct ArchiveBranchDefaultTests {
    private func workspace(branch: String, base: String) -> Workspace {
        Workspace(repoID: RepoID("repo"), name: branch, branch: branch, path: "/tmp/\(branch)", baseBranch: base)
    }

    @Test("a branch of its own follows the request first and the settings second")
    func followsRequestThenSettings() {
        var settings = RepoSettings()
        let feature = workspace(branch: "feature", base: "trunk")
        #expect(!settings.deleteBranchOnArchive)
        #expect(!RepoSettingsDraft().deleteBranchOnArchive)

        #expect(!ArchiveBranchDeletion.applies(
            requested: nil, settings: settings, workspace: feature, defaultBranch: "trunk"
        ))
        #expect(ArchiveBranchDeletion.applies(
            requested: true, settings: settings, workspace: feature, defaultBranch: "trunk"
        ))
        settings.deleteBranchOnArchive = true
        #expect(ArchiveBranchDeletion.applies(
            requested: nil, settings: settings, workspace: feature, defaultBranch: "trunk"
        ))
        #expect(!ArchiveBranchDeletion.applies(
            requested: false, settings: settings, workspace: feature, defaultBranch: "trunk"
        ))
    }

    @Test("the default branch and the workspace's own base are never deleted, whatever was asked")
    func sparesDefaultAndBase() {
        var settings = RepoSettings()
        settings.deleteBranchOnArchive = true

        #expect(!ArchiveBranchDeletion.applies(
            requested: true, settings: settings,
            workspace: workspace(branch: "trunk", base: "develop"), defaultBranch: "trunk"
        ))
        #expect(!ArchiveBranchDeletion.applies(
            requested: true, settings: settings,
            workspace: workspace(branch: "develop", base: "develop"), defaultBranch: "trunk"
        ))
    }

    @Test("the global file turns deletion on for a project that says nothing")
    func globalFileTurnsItOn() throws {
        let home = TestScratch.unique("unifieddev-home")
        let global = "\(home)/.unifieddev/settings.toml"
        defer { try? FileManager.default.removeItem(atPath: home) }

        #expect(!GlobalWorkspaceSettings.deleteBranchOnArchive(paths: [global]))
        try GlobalWorkspaceSettings.setDeleteBranchOnArchive(true, in: global)
        #expect(GlobalWorkspaceSettings.deleteBranchOnArchive(paths: [global]))

        let repo = TestScratch.unique("unifieddev-project")
        defer { try? FileManager.default.removeItem(atPath: repo) }
        try FileManager.default.createDirectory(atPath: repo, withIntermediateDirectories: true)
        #expect(SettingsLoader.load(repo: repo, homePaths: [global]).deleteBranchOnArchive)

        try GlobalWorkspaceSettings.setDeleteBranchOnArchive(false, in: global)
        #expect(!GlobalWorkspaceSettings.deleteBranchOnArchive(paths: [global]))
    }

    @Test("a project that writes false overrides a global true")
    func projectOverridesGlobal() throws {
        let home = TestScratch.unique("unifieddev-home")
        let global = "\(home)/.unifieddev/settings.toml"
        defer { try? FileManager.default.removeItem(atPath: home) }
        try GlobalWorkspaceSettings.setDeleteBranchOnArchive(true, in: global)

        let repo = TempRepo(existing: TestScratch.unique("unifieddev-project"))
        defer { repo.cleanUp() }
        try repo.write(".unifieddev/settings.toml", """
        [git]
        delete_branch_on_archive = false
        """)

        #expect(!SettingsLoader.load(repo: repo.path, homePaths: [global]).deleteBranchOnArchive)
    }

    @Test("writing the global file keeps what else it holds")
    func globalWriteKeepsOtherKeys() throws {
        let home = TestScratch.unique("unifieddev-home")
        let global = "\(home)/.unifieddev/settings.toml"
        defer { try? FileManager.default.removeItem(atPath: home) }
        try FileManager.default.createDirectory(
            atPath: (global as NSString).deletingLastPathComponent, withIntermediateDirectories: true
        )
        try "[git]\nbranch_prefix = \"kid/\"\n".write(toFile: global, atomically: true, encoding: .utf8)

        try GlobalWorkspaceSettings.setDeleteBranchOnArchive(true, in: global)

        let loaded = SettingsLoader.loadHome(paths: [global])
        #expect(loaded.deleteBranchOnArchive)
        #expect(loaded.branchPrefix == "kid/")
    }

    @Test("the file the toggle writes is one the loader reads, and the suite never reads this machine's")
    func toggleWritesWhatTheLoaderReads() {
        #expect(SettingsLoader.homePaths().contains(GlobalWorkspaceSettings.file))
        #expect(SettingsLoader.homeDirectory != NSHomeDirectory())
    }

    @Test("writing through a symlinked global file keeps the link and edits its target")
    func globalWriteFollowsSymlink() throws {
        let home = TestScratch.unique("unifieddev-home")
        defer { try? FileManager.default.removeItem(atPath: home) }
        let dotfiles = "\(home)/dotfiles/settings.toml"
        let global = "\(home)/.unifieddev/settings.toml"
        try FileManager.default.createDirectory(atPath: "\(home)/dotfiles", withIntermediateDirectories: true)
        try FileManager.default.createDirectory(atPath: "\(home)/.unifieddev", withIntermediateDirectories: true)
        try "[git]\nbranch_prefix = \"kid/\"\n".write(toFile: dotfiles, atomically: true, encoding: .utf8)
        try FileManager.default.createSymbolicLink(atPath: global, withDestinationPath: dotfiles)

        try GlobalWorkspaceSettings.setDeleteBranchOnArchive(true, in: global)

        #expect(try FileManager.default.destinationOfSymbolicLink(atPath: global) == dotfiles)
        let loaded = SettingsLoader.loadHome(paths: [dotfiles])
        #expect(loaded.deleteBranchOnArchive)
        #expect(loaded.branchPrefix == "kid/")
    }

    @Test("a global file that cannot be read is left alone rather than replaced")
    func unreadableGlobalFileIsNotReplaced() throws {
        let home = TestScratch.unique("unifieddev-home")
        defer { try? FileManager.default.removeItem(atPath: home) }
        let global = "\(home)/.unifieddev/settings.toml"
        try FileManager.default.createDirectory(atPath: "\(home)/.unifieddev", withIntermediateDirectories: true)
        let original = Data([0x5B, 0x67, 0x69, 0x74, 0x5D, 0x0A, 0xFF, 0xFE, 0x0A])
        try original.write(to: URL(fileURLWithPath: global))

        #expect(throws: (any Error).self) {
            try GlobalWorkspaceSettings.setDeleteBranchOnArchive(true, in: global)
        }
        #expect(try Data(contentsOf: URL(fileURLWithPath: global)) == original)
    }

    @Test("archiving a workspace on the default branch keeps that branch even when asked to delete it")
    func defaultBranchSurvivesArchive() async throws {
        let upstream = try await TempRepo()
        defer { upstream.cleanUp() }
        let clonePath = TestScratch.unique("unifieddev-git")
        try await Shell.check("git", ["clone", "-q", upstream.path, clonePath], cwd: upstream.path)
        let clone = TempRepo(existing: clonePath)
        defer { clone.cleanUp() }
        try await Shell.check("git", ["checkout", "-q", "-b", "elsewhere"], cwd: clone.path)

        let manager = WorkspaceManager(store: try makeTestStore("archive-default"))
        let registered = try await manager.addRepository(at: clone.path)
        let workspace = try await manager.createWorkspace(
            repo: registered,
            prompt: "On the default branch",
            checkout: .branch(ExistingBranch(name: registered.defaultBranch, isLocal: true))
        )
        #expect(workspace.branch == registered.defaultBranch)

        try await manager.archive(workspace: workspace, repo: registered, deleteBranch: true)

        #expect(try await manager.store.workspace(id: workspace.id)?.state == .archived)
        #expect(await Git.branchExists(registered.defaultBranch, in: clone.path))
    }
}
