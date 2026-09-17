import Testing
import Foundation
@testable import Core

@Suite("Scripts as files", .scratchDirectory)
struct ScriptFileTests {
    private func makeRepo(_ files: [String: String] = [:]) throws -> String {
        let root = TestScratch.unique("unifieddev-scripts")
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

    private func read(_ repo: String, _ relative: String) -> String? {
        try? String(contentsOfFile: (repo as NSString).appendingPathComponent(relative), encoding: .utf8)
    }

    private func mode(_ repo: String, _ relative: String) throws -> Int? {
        let full = (repo as NSString).appendingPathComponent(relative)
        let attributes = try FileManager.default.attributesOfItem(atPath: full)
        return (attributes[.posixPermissions] as? NSNumber)?.intValue
    }

    @Test("a named file is read as the script")
    func aNamedFileIsRead() throws {
        let repo = try makeRepo([
            ".unifieddev/settings.toml": "[scripts]\nsetup_file = \".unifieddev/setup.sh\"\n",
            ".unifieddev/setup.sh": "#!/bin/zsh\nbun install\n",
        ])

        let settings = SettingsLoader.load(repo: repo)

        #expect(settings.setupScript == "#!/bin/zsh\nbun install\n")
        #expect(settings.scriptFiles[.setup]?.path == ".unifieddev/setup.sh")
        #expect(settings.scriptFiles[.setup]?.isMissing == false)
    }

    @Test("a script embedded by Conductor is still read")
    func anInlineScriptIsStillRead() throws {
        let repo = try makeRepo([
            ".conductor/settings.toml": "[scripts]\nsetup = \"bun install\"\n",
        ])

        let settings = SettingsLoader.load(repo: repo)

        #expect(settings.setupScript == "bun install")
        #expect(settings.scriptFiles[.setup] == nil)
    }

    @Test("inside one file the named file wins over an embedded string")
    func theFileWinsWithinAFile() throws {
        let repo = try makeRepo([
            ".unifieddev/settings.toml": """
            [scripts]
            setup = "the old string"
            setup_file = ".unifieddev/setup.sh"
            """,
            ".unifieddev/setup.sh": "#!/bin/zsh\nthe file\n",
        ])

        #expect(SettingsLoader.load(repo: repo).setupScript == "#!/bin/zsh\nthe file\n")
    }

    @Test("a file named in .unifieddev overrides a string Conductor embedded")
    func unifieddevOutranksConductorAcrossForms() throws {
        let repo = try makeRepo([
            ".conductor/settings.toml": "[scripts]\nsetup = \"the conductor string\"\n",
            ".unifieddev/settings.toml": "[scripts]\nsetup_file = \".unifieddev/setup.sh\"\n",
            ".unifieddev/setup.sh": "#!/bin/zsh\nthe unifieddev file\n",
        ])

        #expect(SettingsLoader.load(repo: repo).setupScript == "#!/bin/zsh\nthe unifieddev file\n")
    }

    @Test("a run script can name a file too")
    func aRunScriptCanNameAFile() throws {
        let repo = try makeRepo([
            ".unifieddev/settings.toml": """
            [scripts.run.dev]
            file = ".unifieddev/run-dev.sh"
            """,
            ".unifieddev/run-dev.sh": "#!/bin/zsh\nbun dev\n",
        ])

        let settings = SettingsLoader.load(repo: repo)

        #expect(settings.runScripts.map(\.id) == ["dev"])
        #expect(settings.runScripts.first?.command == "#!/bin/zsh\nbun dev\n")
        #expect(settings.scriptFiles[.run("dev")]?.isMissing == false)
    }

    @Test("a script with a shebang is written out as a file, and the settings point at it")
    func aProgramBecomesAFile() throws {
        let repo = try makeRepo()
        let script = "#!/bin/zsh\nset -euo pipefail\nbun install\n"

        try SettingsWriter.write([.setupScript(script)], repo: repo, settings: RepoSettings())

        #expect(read(repo, ".unifieddev/setup.sh") == script)
        let settings = read(repo, ".unifieddev/settings.toml") ?? ""
        #expect(settings.contains("setup_file = \".unifieddev/setup.sh\""))
        #expect(!settings.contains("\nsetup ="))
    }

    @Test("the file Unified Dev writes can actually be run")
    func theFileIsExecutable() throws {
        let repo = try makeRepo()
        try SettingsWriter.write(
            [.setupScript("#!/bin/zsh\nbun install")], repo: repo, settings: RepoSettings()
        )

        #expect(try mode(repo, ".unifieddev/setup.sh") == 0o755)
    }

    @Test("a script written without a closing newline gets one")
    func aScriptEndsWithANewline() throws {
        let repo = try makeRepo()
        try SettingsWriter.write(
            [.setupScript("#!/bin/zsh\nbun install")], repo: repo, settings: RepoSettings()
        )

        #expect(read(repo, ".unifieddev/setup.sh") == "#!/bin/zsh\nbun install\n")
    }

    @Test("one command stays a string, where it reads best")
    func oneLineStaysInline() throws {
        let repo = try makeRepo()
        try SettingsWriter.write([.setupScript("bun install")], repo: repo, settings: RepoSettings())

        #expect(read(repo, ".unifieddev/setup.sh") == nil)
        #expect(read(repo, ".unifieddev/settings.toml")?.contains("setup = \"bun install\"") == true)
    }

    @Test("a string Conductor embedded is moved to a file the first time it is edited")
    func anInlineConductorScriptIsPromoted() throws {
        let conductor = "[scripts]\nsetup = \"bun install\"\n"
        let repo = try makeRepo([".conductor/settings.toml": conductor])
        let settings = SettingsLoader.load(repo: repo)

        try SettingsWriter.write(
            [.setupScript("#!/bin/zsh\nbun install\nbun run build\n")], repo: repo, settings: settings
        )

        #expect(read(repo, ".unifieddev/setup.sh")?.hasPrefix("#!/bin/zsh") == true)
        #expect(read(repo, ".unifieddev/settings.toml")?.contains("setup_file") == true)
        #expect(read(repo, ".conductor/settings.toml") == conductor)
        #expect(SettingsLoader.load(repo: repo).setupScript == "#!/bin/zsh\nbun install\nbun run build\n")
    }

    @Test("a string Unified Dev itself wrote earlier is moved to a file, not left behind")
    func anInlineAppScriptIsMigrated() throws {
        let script = "#!/bin/zsh\nbun install\n"
        let repo = try makeRepo([
            ".unifieddev/settings.toml": "[scripts]\nsetup = \"\"\"\n#!/bin/zsh\nbun install\n\"\"\"\n",
        ])
        let settings = SettingsLoader.load(repo: repo)
        #expect(settings.setupScript?.contains("bun install") == true)

        try SettingsWriter.write([.setupScript(script + "bun run build\n")], repo: repo, settings: settings)

        let written = read(repo, ".unifieddev/settings.toml") ?? ""
        #expect(written.contains("setup_file = \".unifieddev/setup.sh\""))
        #expect(!written.contains("bun install"))
        #expect(read(repo, ".unifieddev/setup.sh")?.contains("bun run build") == true)
    }

    @Test("a path somebody chose by hand is kept rather than repointed at Unified Dev's own name")
    func aStatedPathIsKept() throws {
        let repo = try makeRepo([
            ".unifieddev/settings.toml": "[scripts]\nsetup_file = \"bin/dev-setup.sh\"\n",
            "bin/dev-setup.sh": "#!/bin/zsh\nold\n",
        ])
        let settings = SettingsLoader.load(repo: repo)

        try SettingsWriter.write([.setupScript("#!/bin/zsh\nnew\n")], repo: repo, settings: settings)

        #expect(read(repo, "bin/dev-setup.sh") == "#!/bin/zsh\nnew\n")
        #expect(read(repo, ".unifieddev/setup.sh") == nil)
        #expect(read(repo, ".unifieddev/settings.toml")?.contains("bin/dev-setup.sh") == true)
    }

    @Test("a personal script does not overwrite the one the team shares")
    func aLocalScriptGetsItsOwnFile() throws {
        let repo = try makeRepo([
            ".unifieddev/settings.local.toml": "[scripts]\nsetup = \"mine\"\n",
        ])
        let settings = SettingsLoader.load(repo: repo)

        try SettingsWriter.write(
            [.setupScript("#!/bin/zsh\nmine, longer\n")], repo: repo, settings: settings
        )

        #expect(read(repo, ".unifieddev/setup.local.sh")?.contains("mine, longer") == true)
        #expect(read(repo, ".unifieddev/setup.sh") == nil)
        #expect(read(repo, ".unifieddev/settings.local.toml")?.contains("setup.local.sh") == true)
    }

    @Test("the ignore rule keeps a personal script out of git and the shared one in")
    func theIgnoreRuleCoversScripts() throws {
        let repo = try makeRepo()
        try SettingsWriter.write(
            [.setupScript("#!/bin/zsh\nbun install\n")], repo: repo, settings: RepoSettings()
        )

        let ignore = read(repo, ".unifieddev/.gitignore") ?? ""
        #expect(ignore.contains("*.local.sh"))
        #expect(!ignore.contains("\nsetup.sh"))
    }

    @Test("a run script long enough to be a program gets a file of its own")
    func aLongRunScriptBecomesAFile() throws {
        let repo = try makeRepo()
        let scripts = [
            RunScript(id: "dev", name: "Dev", command: "bun dev"),
            RunScript(id: "test", name: "Test", command: "#!/bin/zsh\nbun test --watch\n"),
        ]

        try SettingsWriter.write([.runScripts(scripts)], repo: repo, settings: RepoSettings())

        let settings = read(repo, ".unifieddev/settings.toml") ?? ""
        #expect(settings.contains("command = \"bun dev\""))
        #expect(settings.contains("file = \".unifieddev/run-test.sh\""))
        #expect(read(repo, ".unifieddev/run-test.sh")?.contains("bun test --watch") == true)
        #expect(read(repo, ".unifieddev/run-dev.sh") == nil)
    }

    @Test("what the writer writes is what the loader reads back")
    func roundTripsThroughTheLoader() throws {
        let repo = try makeRepo()
        let setup = "#!/bin/zsh\nset -euo pipefail\ncp .env.example .env\nbun install\n"

        try SettingsWriter.write(
            [.setupScript(setup), .archiveScript("#!/bin/zsh\ndocker compose down\n")],
            repo: repo, settings: RepoSettings()
        )

        let settings = SettingsLoader.load(repo: repo)
        #expect(settings.setupScript == setup)
        #expect(settings.archiveScript == "#!/bin/zsh\ndocker compose down\n")
        #expect(settings.scriptFiles[.setup]?.path == ".unifieddev/setup.sh")
        #expect(settings.scriptFiles[.archive]?.path == ".unifieddev/archive.sh")
    }

    @Test("clearing a script takes the pointer out and leaves the file where it is")
    func clearingRemovesThePointer() throws {
        let repo = try makeRepo()
        try SettingsWriter.write(
            [.setupScript("#!/bin/zsh\nbun install\n")], repo: repo, settings: RepoSettings()
        )
        let settings = SettingsLoader.load(repo: repo)

        try SettingsWriter.write([.setupScript(nil)], repo: repo, settings: settings)

        #expect(read(repo, ".unifieddev/settings.toml")?.contains("setup_file") == false)
        #expect(SettingsLoader.load(repo: repo).setupScript == nil)
        #expect(read(repo, ".unifieddev/setup.sh")?.contains("bun install") == true)
    }

    @Test("a settings file naming a script that is not there says so rather than pretending")
    func aMissingFileIsReported() throws {
        let repo = try makeRepo([
            ".unifieddev/settings.toml": "[scripts]\nsetup_file = \".unifieddev/setup.sh\"\n",
        ])

        let settings = SettingsLoader.load(repo: repo)

        #expect(settings.setupScript == nil)
        #expect(settings.scriptFiles[.setup]?.path == ".unifieddev/setup.sh")
        #expect(settings.scriptFiles[.setup]?.isMissing == true)
        #expect(settings.origins[.setupScript] != nil)
    }

    @Test("a missing file is written again at the path the settings already name")
    func aMissingFileIsRepairedInPlace() throws {
        let repo = try makeRepo([
            ".unifieddev/settings.toml": "[scripts]\nsetup_file = \"bin/dev-setup.sh\"\n",
        ])
        let settings = SettingsLoader.load(repo: repo)

        try SettingsWriter.write([.setupScript("#!/bin/zsh\nback\n")], repo: repo, settings: settings)

        #expect(read(repo, "bin/dev-setup.sh") == "#!/bin/zsh\nback\n")
        #expect(try mode(repo, "bin/dev-setup.sh") == 0o755)
    }

    @Test("a file with a shebang, marked executable, is run as itself")
    func anExecutableFileIsRunDirectly() throws {
        let repo = try makeRepo()
        try SettingsWriter.write(
            [.setupScript("#!/bin/zsh\nbun install\n")], repo: repo, settings: RepoSettings()
        )
        let settings = SettingsLoader.load(repo: repo)

        let launch = ScriptLaunch.resolve(
            text: settings.setupScript, file: settings.scriptFiles[.setup], repo: repo
        )

        #expect(launch == .executable(path: (repo as NSString).appendingPathComponent(".unifieddev/setup.sh")))
        #expect(launch?.arguments == [])
    }

    @Test("a file with no shebang cannot introduce itself, so its text is run as before")
    func aFileWithoutAShebangIsSourced() throws {
        let repo = try makeRepo([
            ".unifieddev/settings.toml": "[scripts]\nsetup_file = \".unifieddev/setup.sh\"\n",
            ".unifieddev/setup.sh": "bun install\n",
        ])
        let settings = SettingsLoader.load(repo: repo)

        let launch = ScriptLaunch.resolve(
            text: settings.setupScript, file: settings.scriptFiles[.setup], repo: repo
        )

        #expect(launch == .source("bun install\n"))
        #expect(launch?.executable == "/bin/zsh")
    }

    @Test("a file whose executable bit was lost still runs")
    func aFileWithoutTheBitIsSourced() throws {
        let repo = try makeRepo([
            ".unifieddev/settings.toml": "[scripts]\nsetup_file = \".unifieddev/setup.sh\"\n",
            ".unifieddev/setup.sh": "#!/bin/zsh\nbun install\n",
        ])
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o644],
            ofItemAtPath: (repo as NSString).appendingPathComponent(".unifieddev/setup.sh")
        )
        let settings = SettingsLoader.load(repo: repo)

        let launch = ScriptLaunch.resolve(
            text: settings.setupScript, file: settings.scriptFiles[.setup], repo: repo
        )

        #expect(launch == .source("#!/bin/zsh\nbun install\n"))
    }

    @Test("a script embedded in the settings file runs the way it always did")
    func anInlineScriptIsSourced() throws {
        let repo = try makeRepo([".unifieddev/settings.toml": "[scripts]\nsetup = \"bun install\"\n"])
        let settings = SettingsLoader.load(repo: repo)

        let launch = ScriptLaunch.resolve(
            text: settings.setupScript, file: settings.scriptFiles[.setup], repo: repo
        )

        #expect(launch == .source("bun install"))
        #expect(launch?.arguments == ["-c", "bun install"])
    }

    @Test("a named file that is not there is a broken pointer, not an absent script")
    func aMissingFileIsItsOwnAnswer() throws {
        let repo = try makeRepo([
            ".unifieddev/settings.toml": "[scripts]\nsetup_file = \".unifieddev/setup.sh\"\n",
        ])
        let settings = SettingsLoader.load(repo: repo)

        let launch = ScriptLaunch.resolve(
            text: settings.setupScript, file: settings.scriptFiles[.setup], repo: repo
        )

        #expect(launch == .missing(path: ".unifieddev/setup.sh"))
        #expect(launch?.executable == "/bin/zsh")
        #expect(launch?.arguments == ["-c", "true"])
    }

    @Test("no script at all is no launch at all")
    func noScriptIsNoLaunch() throws {
        let repo = try makeRepo()
        let settings = SettingsLoader.load(repo: repo)

        #expect(ScriptLaunch.resolve(
            text: settings.setupScript, file: settings.scriptFiles[.setup], repo: repo
        ) == nil)
    }
}
