import Foundation
import Testing
@testable import Core

@Suite("Archiving a workspace once its pull request merges", .scratchDirectory)
struct ArchiveOnMergeSettingTests {
    private func makeRepo(_ files: [String: String] = [:]) throws -> String {
        let root = TestScratch.unique("unifieddev-archive-on-merge")
        try FileManager.default.createDirectory(atPath: root, withIntermediateDirectories: true)
        for (relative, contents) in files {
            let full = (root as NSString).appendingPathComponent(relative)
            try FileManager.default.createDirectory(
                atPath: (full as NSString).deletingLastPathComponent,
                withIntermediateDirectories: true
            )
            try contents.write(toFile: full, atomically: true, encoding: .utf8)
        }
        return root
    }

    private func globalFile() -> String {
        "\(TestScratch.unique("unifieddev-home"))/.unifieddev/settings.toml"
    }

    @Test("it is on when no file says otherwise")
    func isOnWhenNothingSaysOtherwise() throws {
        let repo = try makeRepo()
        #expect(RepoSettings().archiveOnMerge)
        #expect(RepoSettingsDraft().archiveOnMerge)
        #expect(SettingsLoader.load(repo: repo, homePaths: []).archiveOnMerge)
        #expect(GlobalWorkspaceSettings.archiveOnMerge(paths: [globalFile()]))
    }

    @Test("a project overrides the global file in either direction")
    func projectOverridesGlobal() throws {
        let global = globalFile()
        try GlobalWorkspaceSettings.setArchiveOnMerge(false, in: global)
        #expect(!GlobalWorkspaceSettings.archiveOnMerge(paths: [global]))

        let silent = try makeRepo()
        #expect(!SettingsLoader.load(repo: silent, homePaths: [global]).archiveOnMerge)

        let saysYes = try makeRepo([".unifieddev/settings.toml": "[git]\narchive_on_merge = true\n"])
        let loaded = SettingsLoader.load(repo: saysYes, homePaths: [global])
        #expect(loaded.archiveOnMerge)
        #expect(loaded.origins[.archiveOnMerge]?.hasPrefix(saysYes) == true)

        try GlobalWorkspaceSettings.setArchiveOnMerge(true, in: global)
        let saysNo = try makeRepo([".unifieddev/settings.toml": "[git]\narchive_on_merge = false\n"])
        #expect(!SettingsLoader.load(repo: saysNo, homePaths: [global]).archiveOnMerge)
    }

    @Test("the local file outranks the shared one")
    func localOutranksShared() throws {
        let repo = try makeRepo([
            ".unifieddev/settings.toml": "[git]\narchive_on_merge = true\n",
            ".unifieddev/settings.local.toml": "[git]\narchive_on_merge = false\n",
        ])
        #expect(!SettingsLoader.load(repo: repo, homePaths: []).archiveOnMerge)
    }

    @Test("what the draft writes is what the loader reads back")
    func roundTripsThroughTheWriter() throws {
        let repo = try makeRepo()
        let settings = SettingsLoader.load(repo: repo, homePaths: [])
        var draft = RepoSettingsDraft(settings)
        draft.archiveOnMerge = false

        let edits = draft.edits(comparedTo: settings)
        #expect(edits == [.archiveOnMerge(false)])

        try SettingsWriter.write(edits, repo: repo, settings: settings)
        let reloaded = SettingsLoader.load(repo: repo, homePaths: [])
        #expect(!reloaded.archiveOnMerge)
        #expect(RepoSettingsDraft(reloaded).edits(comparedTo: reloaded).isEmpty)
    }
}
