import Testing
import Foundation
@testable import Core

@Suite("Settings writer", .scratchDirectory)
struct SettingsWriterTests {
    private func makeRepo(_ files: [String: String] = [:]) throws -> String {
        let root = TestScratch.unique("unifieddev-writer")
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

    private func trimmed(_ text: String?) -> String? {
        text?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func read(_ repo: String, _ relative: String) -> String? {
        try? String(contentsOfFile: (repo as NSString).appendingPathComponent(relative), encoding: .utf8)
    }

    @Test("what a project says about merging survives being written and read back")
    func instructionsRoundTrip() throws {
        let repo = try makeRepo()
        let text = "Squash unless the branch is a stack.\n\nNever merge on a Friday."

        try SettingsWriter.write(
            [.mergeInstructions(text), .conflictInstructions("Regenerate the lock file.")],
            repo: repo, settings: RepoSettings()
        )
        let settings = SettingsLoader.load(repo: repo)

        #expect(trimmed(ProjectInstructions.stated(.merge, in: settings)) == text)
        #expect(trimmed(ProjectInstructions.stated(.fixConflicts, in: settings))
            == "Regenerate the lock file.")
    }

    @Test("instructions are never moved into a file of their own")
    func instructionsStayInTheSettingsFile() throws {
        let repo = try makeRepo()

        try SettingsWriter.write(
            [.mergeInstructions("#!/bin/zsh\nnot a script, but it starts like one")],
            repo: repo, settings: RepoSettings()
        )

        #expect(read(repo, ".unifieddev/settings.toml")?.contains("not a script") == true)
        #expect(read(repo, ".unifieddev/merge-instructions.md") == nil)
    }

    @Test("clearing the box takes the line out")
    func clearingTakesTheLineOut() throws {
        let repo = try makeRepo([".unifieddev/settings.toml": "[instructions]\nmerge = \"Squash.\"\n"])
        let settings = SettingsLoader.load(repo: repo)

        try SettingsWriter.write([.mergeInstructions(nil)], repo: repo, settings: settings)

        #expect(SettingsLoader.load(repo: repo).mergeInstructions == nil)
        #expect(read(repo, ".unifieddev/settings.toml")?.contains("merge") == false)
    }

    @Test("an edit to a value Unified Dev's own file states goes back to that file")
    func editsGoBackToTheirOrigin() throws {
        let repo = try makeRepo([
            ".unifieddev/settings.toml": "[scripts]\nsetup = \"shared\"\n",
            ".unifieddev/settings.local.toml": "[scripts]\narchive = \"mine\"\n",
        ])
        let settings = SettingsLoader.load(repo: repo)

        #expect(
            SettingsWriter.destination(for: .setupScript, in: settings, repo: repo)
                == (repo as NSString).appendingPathComponent(".unifieddev/settings.toml")
        )
        #expect(
            SettingsWriter.destination(for: .archiveScript, in: settings, repo: repo)
                == (repo as NSString).appendingPathComponent(".unifieddev/settings.local.toml")
        )
    }

    @Test("a value read out of .conductor is written to .unifieddev at the same tier")
    func conductorValuesAreWrittenToUnifiedDev() throws {
        let repo = try makeRepo([
            ".conductor/settings.toml": "[scripts]\nsetup = \"shared\"\n",
            ".conductor/settings.local.toml": "[scripts]\narchive = \"mine\"\n",
        ])
        let settings = SettingsLoader.load(repo: repo)

        #expect(
            SettingsWriter.destination(for: .setupScript, in: settings, repo: repo)
                == (repo as NSString).appendingPathComponent(".unifieddev/settings.toml")
        )
        #expect(
            SettingsWriter.destination(for: .archiveScript, in: settings, repo: repo)
                == (repo as NSString).appendingPathComponent(".unifieddev/settings.local.toml")
        )
    }

    @Test("writing to .unifieddev leaves the .conductor file exactly as the team committed it")
    func conductorFilesAreNeverRewritten() throws {
        let original = "[scripts]\nsetup = \"pnpm install\"\n"
        let repo = try makeRepo([".conductor/settings.toml": original])
        let settings = SettingsLoader.load(repo: repo)

        try SettingsWriter.write([.setupScript("bun install")], repo: repo, settings: settings)

        #expect(read(repo, ".conductor/settings.toml") == original)
        #expect(read(repo, ".unifieddev/settings.toml")?.contains("bun install") == true)
        #expect(SettingsLoader.load(repo: repo).setupScript == "bun install")
    }

    @Test("a script a .conductor file states can still be cleared")
    func clearingOverridesTheFileBelow() throws {
        let repo = try makeRepo([".conductor/settings.toml": "[scripts]\nsetup = \"pnpm install\"\n"])
        let settings = SettingsLoader.load(repo: repo)

        try SettingsWriter.write([.setupScript("")], repo: repo, settings: settings)

        #expect(read(repo, ".unifieddev/settings.toml")?.contains("setup = \"\"") == true)
        #expect(SettingsLoader.load(repo: repo).setupScript == nil)
    }

    @Test("a value only a machine-wide file states is not edited there")
    func homeFilesAreNeverRewritten() throws {
        let repo = try makeRepo()
        var settings = RepoSettings()
        settings.origins[.branchPrefix] = "\(NSHomeDirectory())/.unifieddev/settings.toml"

        #expect(
            SettingsWriter.destination(for: .branchPrefix, in: settings, repo: repo)
                == (repo as NSString).appendingPathComponent(".unifieddev/settings.toml")
        )
    }

    @Test("a setting nobody states yet goes to Unified Dev's own shared file")
    func defaultFileIsAlwaysUnifiedDev() throws {
        let onlyConductor = try makeRepo([".conductor/settings.toml": "[scripts]\nsetup = \"x\"\n"])
        #expect(
            SettingsWriter.defaultFile(repo: onlyConductor)
                == (onlyConductor as NSString).appendingPathComponent(".unifieddev/settings.toml")
        )

        let bare = try makeRepo()
        #expect(
            SettingsWriter.defaultFile(repo: bare)
                == (bare as NSString).appendingPathComponent(".unifieddev/settings.toml")
        )
    }

    @Test("the folder Unified Dev creates keeps the personal file out of git")
    func unifieddevFolderCarriesItsOwnIgnoreRule() throws {
        let repo = try makeRepo()
        try SettingsWriter.write([.setupScript("bun install")], repo: repo, settings: RepoSettings())

        #expect(read(repo, ".unifieddev/.gitignore") == "settings.local.toml\n*.local.sh\n")
    }

    @Test("a .gitignore already in the folder is left alone")
    func anExistingIgnoreFileIsNotRewritten() throws {
        let repo = try makeRepo([".unifieddev/.gitignore": "# mine\n"])
        try SettingsWriter.write([.setupScript("bun install")], repo: repo, settings: RepoSettings())
        #expect(read(repo, ".unifieddev/.gitignore") == "# mine\n")
    }

    @Test("what the writer writes is what the loader reads back")
    func roundTripsThroughTheLoader() throws {
        let repo = try makeRepo()
        var settings = SettingsLoader.load(repo: repo)

        try SettingsWriter.write(
            [
                .setupScript("set -e\ncomposer install"),
                .filesToCopy([".env*", "certs/*.pem"]),
                .runScripts([
                    RunScript(id: "dev", name: "Dev", command: "bun dev --port $UD_PORT"),
                    RunScript(id: "test", name: "Watch tests", command: "bun test --watch"),
                ]),
                .branchPrefix("freek"),
                .deleteBranchOnArchive(true),
                .runMode("concurrent"),
                .browserURL("http://localhost:$UD_PORT/admin"),
            ],
            repo: repo,
            settings: settings
        )

        settings = SettingsLoader.load(repo: repo)
        #expect(settings.setupScript?.trimmingCharacters(in: .newlines) == "set -e\ncomposer install")
        #expect(settings.filesToCopy == [".env*", "certs/*.pem"])
        #expect(settings.runScripts.map(\.id) == ["dev", "test"])
        #expect(settings.runScripts.map(\.name) == ["Dev", "Watch tests"])
        #expect(settings.runScripts.first?.command == "bun dev --port $UD_PORT")
        #expect(settings.branchPrefix == "freek")
        #expect(settings.deleteBranchOnArchive)
        #expect(settings.runMode == "concurrent")
        #expect(settings.browserURL == "http://localhost:$UD_PORT/admin")
    }

    @Test("clearing a value removes the key rather than writing an empty one")
    func clearingRemovesTheKey() throws {
        let repo = try makeRepo([".unifieddev/settings.toml": "[scripts]\nsetup = \"x\"\narchive = \"y\"\n"])
        let settings = SettingsLoader.load(repo: repo)

        try SettingsWriter.write([.setupScript("")], repo: repo, settings: settings)

        #expect(read(repo, ".unifieddev/settings.toml")?.contains("setup") == false)
        #expect(read(repo, ".unifieddev/settings.toml")?.contains("archive") == true)
        #expect(SettingsLoader.load(repo: repo).setupScript == nil)
    }

    @Test("an empty glob list is written, so 'copy nothing' is expressible")
    func emptyGlobListMeansNothing() throws {
        let repo = try makeRepo()
        try SettingsWriter.write([.filesToCopy([])], repo: repo, settings: RepoSettings())
        #expect(SettingsLoader.load(repo: repo).filesToCopy == [])
    }

    @Test("a removed run script takes its table with it")
    func removingARunScriptRemovesItsTable() throws {
        let repo = try makeRepo([
            ".unifieddev/settings.toml": """
            [scripts.run.dev]
            command = "bun dev"

            [scripts.run.test]
            command = "bun test"
            """,
        ])
        let settings = SettingsLoader.load(repo: repo)
        #expect(settings.runScripts.count == 2)

        try SettingsWriter.write(
            [.runScripts([RunScript(id: "dev", name: "Dev", command: "bun dev")])],
            repo: repo,
            settings: settings
        )

        let after = SettingsLoader.load(repo: repo)
        #expect(after.runScripts.map(\.id) == ["dev"])
        #expect(read(repo, ".unifieddev/settings.toml")?.contains("scripts.run.test") == false)
    }

    @Test("the legacy single-string run script is replaced, not left to fight the new tables")
    func legacyRunStringIsReplaced() throws {
        let repo = try makeRepo([".unifieddev/settings.toml": "[scripts]\nrun = \"make serve\"\n"])
        let settings = SettingsLoader.load(repo: repo)
        #expect(settings.runScripts.map(\.command) == ["make serve"])

        try SettingsWriter.write(
            [.runScripts([RunScript(id: "dev", name: "Dev", command: "bun dev")])],
            repo: repo,
            settings: settings
        )

        #expect(read(repo, ".unifieddev/settings.toml")?.contains("run = ") == false)
        #expect(SettingsLoader.load(repo: repo).runScripts.map(\.command) == ["bun dev"])
    }

    @Test("a teammate's comments and unknown keys survive an edit")
    func aTeamFileSurvives() throws {
        let original = """
        "$schema" = "https://conductor.build/schemas/settings.repo.schema.json"

        # Needed because the CI image has no bun.
        [scripts]
        setup = "pnpm install"

        [scripts.run.dev]
        available_in = [ "local" ]
        command = "pnpm dev"
        icon = "play"
        """
        let repo = try makeRepo([".unifieddev/settings.toml": original])
        let settings = SettingsLoader.load(repo: repo)

        try SettingsWriter.write([.setupScript("bun install")], repo: repo, settings: settings)

        let after = try #require(read(repo, ".unifieddev/settings.toml"))
        #expect(after.contains("# Needed because the CI image has no bun."))
        #expect(after.contains("icon = \"play\""))
        #expect(after.contains("available_in = [ \"local\" ]"))
        #expect(after.contains("$schema"))
        #expect(after.contains("setup = \"bun install\""))
    }

    @Test("a change made on disk in the meantime is not clobbered")
    func aConcurrentChangeToAnotherKeySurvives() throws {
        let repo = try makeRepo([".unifieddev/settings.toml": "[scripts]\nsetup = \"old\"\n"])
        let settings = SettingsLoader.load(repo: repo)

        try "[scripts]\nsetup = \"old\"\narchive = \"added behind our back\"\n"
            .write(
                toFile: (repo as NSString).appendingPathComponent(".unifieddev/settings.toml"),
                atomically: true,
                encoding: .utf8
            )

        try SettingsWriter.write([.setupScript("new")], repo: repo, settings: settings)

        let after = SettingsLoader.load(repo: repo)
        #expect(after.setupScript == "new")
        #expect(after.archiveScript == "added behind our back")
    }

    @Test("editing run scripts keeps an icon and autostart written by hand, byte for byte")
    func runScriptExtrasSurviveAnEdit() throws {
        let original = """
        [scripts.run.vite]
        name = "Vite Server"
        command = "yarn dev"
        icon = "bolt"
        autostart = true

        [scripts.run.seed]
        name = "Seed Database"
        command = "php artisan migrate:fresh --seed"
        autostart = false

        """
        let repo = try makeRepo([".unifieddev/settings.toml": original])
        let settings = SettingsLoader.load(repo: repo)

        var draft = RepoSettingsDraft(settings)
        #expect(draft.edits(comparedTo: settings).isEmpty)
        draft.runScripts[1].command = "php artisan migrate:fresh --seed --force"
        try SettingsWriter.write(draft.edits(comparedTo: settings), repo: repo, settings: settings)

        let after = try #require(read(repo, ".unifieddev/settings.toml"))
        #expect(after == original.replacingOccurrences(of: "--seed\"", with: "--seed --force\""))
        let reloaded = SettingsLoader.load(repo: repo)
        #expect(reloaded.runScripts.map(\.icon) == ["bolt", nil])
        #expect(reloaded.runScripts.map(\.autostart) == [true, false])
    }

    @Test("run scripts moved into .unifieddev from .conductor take their icon and autostart with them")
    func runScriptExtrasFollowTheScriptToUnifiedDev() throws {
        let repo = try makeRepo([
            ".conductor/settings.toml": "[scripts.run.vite]\ncommand = \"yarn dev\"\nicon = \"bolt\"\nautostart = true\n",
        ])
        let settings = SettingsLoader.load(repo: repo)
        var draft = RepoSettingsDraft(settings)
        draft.runScripts[0].name = "Vite Server"

        try SettingsWriter.write(draft.edits(comparedTo: settings), repo: repo, settings: settings)

        let reloaded = SettingsLoader.load(repo: repo)
        #expect(reloaded.origins[.runScripts]?.hasSuffix(".unifieddev/settings.toml") == true)
        #expect(reloaded.runScripts == [
            RunScript(id: "vite", name: "Vite Server", command: "yarn dev", icon: "bolt", autostart: true),
        ])
    }

    @Test("a run script the loader skipped as broken is not deleted by saving the others")
    func skippedRunScriptTablesSurvive() throws {
        let repo = try makeRepo([
            ".unifieddev/settings.toml": """
            [scripts.run.dev]
            command = "bun dev"

            [scripts.run.broken]
            command = "bun test"
            autostart = "yes"
            """,
        ])
        let settings = SettingsLoader.load(repo: repo)
        #expect(settings.runScripts.map(\.id) == ["dev"])

        var draft = RepoSettingsDraft(settings)
        draft.runScripts[0].command = "bun dev --host"
        draft.runScripts.append(DraftRunScript(name: "Broken", command: "echo new"))
        try SettingsWriter.write(draft.edits(comparedTo: settings), repo: repo, settings: settings)

        let after = try #require(read(repo, ".unifieddev/settings.toml"))
        #expect(after.contains("[scripts.run.broken]\ncommand = \"bun test\"\nautostart = \"yes\""))
        #expect(after.contains("[scripts.run.broken-2]"))
    }

    @Test("writing nothing new creates no file")
    func noChangeMeansNoFile() throws {
        let repo = try makeRepo()
        let written = try SettingsWriter.write([.setupScript(nil)], repo: repo, settings: RepoSettings())
        #expect(written.isEmpty)
        #expect(read(repo, ".unifieddev/settings.toml") == nil)
    }
}
