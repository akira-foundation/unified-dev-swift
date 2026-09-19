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

    @Test("a repository with an executable hook is refused, and the card says to add it by hand")
    func refusesAnExecutableHook() async throws {
        let repo = try await TempRepo()
        defer { repo.cleanUp() }
        try repo.write(".git/hooks/post-checkout", "#!/bin/sh\nexit 0\n")
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o755], ofItemAtPath: repo.path + "/.git/hooks/post-checkout"
        )
        let manager = try manager("folder-hook")

        let admitted = await WorkSuggestionLaunch.admit(repo.path, with: manager)
        let projects = try await manager.store.repos()

        guard case .failure(let refusal) = admitted else { Issue.record("\(admitted)"); return }
        #expect(refusal.sentence.contains("post-checkout"))
        #expect(refusal.sentence.contains("Add Project"))
        #expect(projects.isEmpty)
    }

    @Test("a repository whose own configuration runs a program is refused", arguments: [
        ["core.fsmonitor", "/tmp/watch.sh"],
        ["core.hooksPath", "tools/hooks"],
    ])
    func refusesConfigurationThatRunsCode(setting: [String]) async throws {
        let repo = try await TempRepo()
        defer { repo.cleanUp() }
        try await Shell.check("git", ["config"] + setting, cwd: repo.path)
        let manager = try manager("folder-config")

        let admitted = await WorkSuggestionLaunch.admit(repo.path, with: manager)
        let projects = try await manager.store.repos()

        guard case .failure(let refusal) = admitted else { Issue.record("\(admitted)"); return }
        #expect(refusal.sentence.contains(setting[0].lowercased()))
        #expect(refusal.sentence.contains("Add Project"))
        #expect(projects.isEmpty)
    }

    @Test("a hook left as a sample, and a watcher switched off, run nothing and are admitted")
    func admitsWhatRunsNothing() async throws {
        let repo = try await TempRepo()
        defer { repo.cleanUp() }
        try repo.write(".git/hooks/post-checkout.sample", "#!/bin/sh\nexit 0\n")
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o755], ofItemAtPath: repo.path + "/.git/hooks/post-checkout.sample"
        )
        try await Shell.check("git", ["config", "core.fsmonitor", "false"], cwd: repo.path)
        let manager = try manager("folder-sample")

        let admitted = await WorkSuggestionLaunch.admit(repo.path, with: manager)

        #expect((try? admitted.get()) != nil, "\(admitted)")
    }

    @Test("a folder inside a repository is refused rather than adding the repository around it")
    func refusesAFolderInsideARepository() async throws {
        let repo = try await TempRepo()
        defer { repo.cleanUp() }
        try repo.write("sub/notes.txt", "notes\n")
        let manager = try manager("folder-inside")

        let admitted = await WorkSuggestionLaunch.admit(repo.path + "/sub", with: manager)
        let projects = try await manager.store.repos()

        guard case .failure(let refusal) = admitted else { Issue.record("\(admitted)"); return }
        #expect(refusal.sentence.contains("inside the repository"))
        #expect(projects.isEmpty)
    }

    @Test("only the repository's own configuration counts, not the owner's global one")
    func onlyTheRepositoryCounts() {
        #expect(RepositoryRunsCode.repositorySetting(in: "global\tcore.hookspath /Users/me/hooks\n") == nil)
        #expect(RepositoryRunsCode.repositorySetting(in: "worktree\tcore.fsmonitor /tmp/w.sh\n") == "core.fsmonitor")
        #expect(RepositoryRunsCode.repositorySetting(in: "local\tcore.fsmonitor off\n") == nil)
        #expect(RepositoryRunsCode.repositorySetting(in: "local\tcore.hookspath\n") == "core.hookspath")
    }
}
