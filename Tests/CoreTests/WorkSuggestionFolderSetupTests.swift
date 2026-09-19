import Foundation
import Testing
@testable import Core

@Suite("A suggested repository with a setup of its own", .tags(.git, .subprocess, .persistence), .scratchDirectory)
struct WorkSuggestionFolderSetupTests {
    private func manager(_ label: String) throws -> WorkspaceManager {
        WorkspaceManager(
            store: try makeTestStore(label),
            workspacesRoot: URL(fileURLWithPath: TestScratch.unique("workspaces"), isDirectory: true)
        )
    }

    private func refusal(_ admitted: Result<Repo, WorkSuggestionRefusal>) -> String? {
        guard case .failure(let refusal) = admitted else { return nil }
        return refusal.sentence
    }

    @Test("a plain repository, fresh from git init and a commit, is admitted")
    func admitsAPlainRepository() async throws {
        let repo = try await PlainRepository()
        defer { repo.cleanUp() }
        let manager = try manager("setup-plain")

        let admitted = await WorkSuggestionLaunch.admit(repo.path, with: manager)
        let projects = try await manager.store.repos()

        #expect((try? admitted.get()) != nil, "\(admitted)")
        #expect(projects.count == 1)
    }

    @Test("a repository with an origin, a tracked branch and a hook left as a sample is admitted")
    func admitsARemoteAndASample() async throws {
        let repo = try await PlainRepository()
        defer { repo.cleanUp() }
        try await Shell.check("git", ["remote", "add", "origin", "https://github.com/octo/parsekit.git"], cwd: repo.path)
        try await repo.configure(["branch.main.remote", "origin"])
        try await repo.configure(["branch.main.merge", "refs/heads/main"])
        try repo.write(".git/hooks/post-checkout.sample", "#!/bin/sh\nexit 0\n", executable: true)
        let manager = try manager("setup-remote")

        let admitted = await WorkSuggestionLaunch.admit(repo.path, with: manager)

        #expect((try? admitted.get()) != nil, "\(admitted)")
    }

    @Test("a repository with an executable hook is refused, and the card says to add it by hand")
    func refusesAnExecutableHook() async throws {
        let repo = try await PlainRepository()
        defer { repo.cleanUp() }
        try repo.write(".git/hooks/post-checkout", "#!/bin/sh\nexit 0\n", executable: true)
        let manager = try manager("setup-hook")

        let admitted = await WorkSuggestionLaunch.admit(repo.path, with: manager)
        let projects = try await manager.store.repos()

        #expect(refusal(admitted)?.contains("post-checkout") == true, "\(admitted)")
        #expect(refusal(admitted)?.contains("Add Project") == true)
        #expect(projects.isEmpty)
    }

    @Test("a repository whose own configuration goes beyond git's plain settings is refused, naming the setting",
          arguments: [
              ["core.hooksPath", "tools/hooks"],
              ["core.fsmonitor", "/tmp/watch.sh"],
              ["core.fsmonitor", "false"],
              ["core.sshCommand", "sh /tmp/evil.sh"],
              ["filter.lfs.smudge", "sh /tmp/evil.sh"],
              ["submodule.vendor.update", "!sh /tmp/evil.sh"],
              ["remote.origin.uploadpack", "sh /tmp/evil.sh"],
              ["protocol.ext.allow", "always"],
              ["include.path", "/tmp/elsewhere.gitconfig"],
          ])
    func refusesSettingsBeyondThePlain(setting: [String]) async throws {
        let repo = try await PlainRepository()
        defer { repo.cleanUp() }
        try await repo.configure(setting)
        try repo.write(".gitattributes", "* filter=lfs\n")
        let manager = try manager("setup-config")

        let admitted = await WorkSuggestionLaunch.admit(repo.path, with: manager)
        let projects = try await manager.store.repos()

        #expect(refusal(admitted)?.contains(setting[0].lowercased()) == true, "\(admitted)")
        #expect(refusal(admitted)?.contains("Add Project") == true)
        #expect(projects.isEmpty)
    }

    @Test("a setting reached through an included file counts as the repository's own")
    func refusesAnIncludedSetting() async throws {
        let repo = try await PlainRepository()
        defer { repo.cleanUp() }
        let included = repo.path + "/.git/extra.gitconfig"
        try "[core]\n\tsshCommand = sh /tmp/evil.sh\n".write(toFile: included, atomically: true, encoding: .utf8)
        try await repo.configure(["include.path", included])
        let listing = try await Shell.check(
            "git", ["config", "--list", "--show-scope", "--includes", "--name-only"], cwd: repo.path
        ).stdout

        #expect(RepositoryOwnSetup.unfamiliarSetting(in: listing) == "include.path")
        #expect(listing.contains("local\tcore.sshcommand"))
    }

    @Test("only the repository's own scopes count, and git's plain keys pass whatever their subsection")
    func onlyTheRepositoryCounts() {
        #expect(RepositoryOwnSetup.unfamiliarSetting(in: "global\tcore.hookspath\nunknown\tcredential.helper\n") == nil)
        #expect(RepositoryOwnSetup.unfamiliarSetting(in: "local\tremote.up.stream.url\nlocal\tbranch.feat/x.merge\n") == nil)
        #expect(RepositoryOwnSetup.unfamiliarSetting(in: "worktree\tcore.fsmonitor\n") == "core.fsmonitor")
        #expect(RepositoryOwnSetup.unfamiliarSetting(in: "local\tremote.origin.pushurl\n") == "remote.origin.pushurl")
        #expect(RepositoryOwnSetup.unfamiliarSetting(in: "local\tcore.url\n") == "core.url")
        #expect(RepositoryOwnSetup.unfamiliarSetting(in: "local\tuser.origin.name\n") == "user.origin.name")
    }
}
