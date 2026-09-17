import Testing
import Foundation
@testable import Core

@Suite("Settings precedence", .scratchDirectory)
struct SettingsPrecedenceTests {
    private func makeRepo(_ files: [String: String]) throws -> String {
        let root = TestScratch.unique("unifieddev-prec")
        for (relative, contents) in files {
            let full = (root as NSString).appendingPathComponent(relative)
            try FileManager.default.createDirectory(
                atPath: (full as NSString).deletingLastPathComponent,
                withIntermediateDirectories: true
            )
            try contents.write(toFile: full, atomically: true, encoding: .utf8)
        }
        try FileManager.default.createDirectory(atPath: root, withIntermediateDirectories: true)
        return root
    }

    @Test(".unifieddev outranks .conductor at the same tier, and .local outranks the shared file")
    func unifieddevOutranksConductor() throws {
        let repo = try makeRepo([
            ".conductor/settings.toml": "[scripts]\nsetup = \"conductor shared\"\n",
            ".unifieddev/settings.toml": "[scripts]\nsetup = \"unifieddev shared\"\n",
        ])
        #expect(SettingsLoader.load(repo: repo).setupScript == "unifieddev shared")

        let withLocals = try makeRepo([
            ".conductor/settings.toml": "[scripts]\nsetup = \"conductor shared\"\n",
            ".unifieddev/settings.toml": "[scripts]\nsetup = \"unifieddev shared\"\n",
            ".conductor/settings.local.toml": "[scripts]\nsetup = \"conductor local\"\n",
        ])
        #expect(SettingsLoader.load(repo: withLocals).setupScript == "conductor local")

        let all = try makeRepo([
            ".conductor/settings.toml": "[scripts]\nsetup = \"conductor shared\"\n",
            ".unifieddev/settings.toml": "[scripts]\nsetup = \"unifieddev shared\"\n",
            ".conductor/settings.local.toml": "[scripts]\nsetup = \"conductor local\"\n",
            ".unifieddev/settings.local.toml": "[scripts]\nsetup = \"unifieddev local\"\n",
        ])
        #expect(SettingsLoader.load(repo: all).setupScript == "unifieddev local")
    }

    @Test("a repository set up for Conductor alone still works with nothing configured")
    func conductorOnlyRepositoriesAreRead() throws {
        let repo = try makeRepo([
            ".conductor/settings.toml": "[scripts]\nsetup = \"pnpm install\"\narchive = \"docker compose down\"\n",
        ])
        let settings = SettingsLoader.load(repo: repo)
        #expect(settings.setupScript == "pnpm install")
        #expect(settings.archiveScript == "docker compose down")
    }

    @Test("a stated empty script beats one a file below states")
    func anEmptyScriptIsAStatement() throws {
        let repo = try makeRepo([
            ".conductor/settings.toml": "[scripts]\nsetup = \"pnpm install\"\n",
            ".unifieddev/settings.toml": "[scripts]\nsetup = \"\"\n",
        ])
        #expect(SettingsLoader.load(repo: repo).setupScript == nil)
    }

    @Test("a repository file lands in the repo layer, not the home layer")
    func repoFileIsRepoScoped() throws {
        let repo = try makeRepo([
            ".conductor/settings.toml": """
            [models]
            default = "haiku"
            """,
        ])
        defer { try? FileManager.default.removeItem(atPath: repo) }

        let settings = SettingsLoader.load(repo: repo)
        #expect(settings.defaultModel == "haiku")

        let bare = try makeRepo([:])
        defer { try? FileManager.default.removeItem(atPath: bare) }
        #expect(settings.homeDefaultModel == SettingsLoader.load(repo: bare).homeDefaultModel)
    }

    @Test("a repository file overrides the home layer")
    func repoBeatsHome() throws {
        let repo = try makeRepo([
            ".conductor/settings.local.toml": """
            [models]
            default = "sonnet"
            """,
        ])
        defer { try? FileManager.default.removeItem(atPath: repo) }

        let settings = SettingsLoader.load(repo: repo)
        #expect(settings.defaultModel == "sonnet")
    }

    @Test("a repository with no model leaves the repo layer empty")
    func silentRepoLeavesRepoLayerEmpty() throws {
        let repo = try makeRepo([
            ".conductor/settings.toml": """
            [scripts]
            setup = "echo hi"
            """,
        ])
        defer { try? FileManager.default.removeItem(atPath: repo) }

        let settings = SettingsLoader.load(repo: repo)
        #expect(settings.defaultModel == nil)
        #expect(settings.setupScript == "echo hi")
    }

    @Test("the two scopes are distinct sets of paths, and together are the old list")
    func scopesPartitionTheCandidates() {
        let repo = "/tmp/example"
        let home = SettingsLoader.homePaths()
        let repoScoped = SettingsLoader.repoPaths(repo: repo)

        #expect(home.allSatisfy { $0.hasPrefix(repo) == false })
        #expect(repoScoped.allSatisfy { $0.hasPrefix(repo) })
        #expect(Set(home).isDisjoint(with: Set(repoScoped)))
        #expect(SettingsLoader.candidatePaths(repo: repo) == home + repoScoped)
    }

    private func resolve(
        repoValue: String?,
        storedValue: String?,
        homeValue: String?,
        fallback: String
    ) -> String {
        var repo = RepoSettings()
        repo.defaultModel = repoValue
        repo.homeDefaultModel = homeValue

        var app = AppDefaults(model: fallback)
        app.storedModel = storedValue

        return ComposerDefaults.resolve(repo: repo, app: app).model
    }

    @Test("resolves the model from the highest layer that has one", arguments: [
        (repo: "haiku", stored: "sonnet", home: "opus-5-1m", expected: "haiku"),
        (repo: nil, stored: "sonnet", home: "opus-5-1m", expected: "sonnet"),
        (repo: nil, stored: nil, home: "opus-5-1m", expected: "opus-5-1m"),
        (repo: nil, stored: nil, home: nil, expected: "opus"),
        (repo: "", stored: "  ", home: "opus-5-1m", expected: "opus-5-1m"),
        (repo: "", stored: "", home: "", expected: "opus"),
    ])
    func resolvesTheModel(repo: String?, stored: String?, home: String?, expected: String) {
        #expect(resolve(repoValue: repo, storedValue: stored, homeValue: home, fallback: "opus") == expected)
    }
}
