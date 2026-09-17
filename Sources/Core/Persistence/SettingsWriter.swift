import Foundation

public enum SettingsEdit: Sendable, Hashable {
    case setupScript(String?)
    case archiveScript(String?)
    case runScripts([RunScript])
    case runMode(String)
    case filesToCopy([String])
    case branchPrefix(String?)
    case deleteBranchOnArchive(Bool)
    case mergeInstructions(String?)
    case conflictInstructions(String?)
    case browserURL(String?)

    public var key: SettingsKey {
        switch self {
        case .setupScript: .setupScript
        case .archiveScript: .archiveScript
        case .runScripts: .runScripts
        case .runMode: .runMode
        case .filesToCopy: .filesToCopy
        case .branchPrefix: .branchPrefix
        case .deleteBranchOnArchive: .deleteBranchOnArchive
        case .mergeInstructions: .mergeInstructions
        case .conflictInstructions: .conflictInstructions
        case .browserURL: .browserURL
        }
    }
}

public enum SettingsWriter {
    public static func destination(for key: SettingsKey, in settings: RepoSettings, repo: String) -> String {
        guard let origin = settings.origins[key],
              SettingsLoader.repoPaths(repo: repo).contains(origin)
        else { return defaultFile(repo: repo) }

        return unifieddevFile(matching: origin, repo: repo)
    }

    static func unifieddevFile(matching path: String, repo: String) -> String {
        let name = (path as NSString).lastPathComponent
        return (repo as NSString).appendingPathComponent(".unifieddev/\(name)")
    }

    public static func defaultFile(repo: String) -> String {
        (repo as NSString).appendingPathComponent(".unifieddev/settings.toml")
    }

    static func prepareFolder(for path: String, repo: String) {
        let manager = FileManager.default
        let folder = (path as NSString).deletingLastPathComponent
        guard folder == (repo as NSString).appendingPathComponent(".unifieddev") else { return }

        let ignore = (folder as NSString).appendingPathComponent(".gitignore")
        guard !manager.fileExists(atPath: ignore) else { return }

        try? manager.createDirectory(atPath: folder, withIntermediateDirectories: true)
        try? "settings.local.toml\n*.local.sh\n".write(
            toFile: ignore, atomically: true, encoding: .utf8
        )
    }

    static func wantsAFile(_ script: String) -> Bool {
        let trimmed = script.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        return trimmed.contains("\n") || trimmed.hasPrefix("#!")
    }

    static func defaultScriptPath(for location: ScriptLocation, local: Bool) -> String {
        let name = switch location {
        case .setup: "setup"
        case .archive: "archive"
        case .run(let id): "run-\(id)"
        }
        return ".unifieddev/\(name)\(local ? ".local" : "").sh"
    }

    static func key(for location: ScriptLocation) -> SettingsKey {
        switch location {
        case .setup: .setupScript
        case .archive: .archiveScript
        case .run: .runScripts
        }
    }

    public static func scriptFile(
        for location: ScriptLocation, script: String, in settings: RepoSettings, repo: String
    ) -> String? {
        guard !script.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        if let stated = settings.scriptFiles[location]?.path, !stated.isEmpty { return stated }
        guard wantsAFile(script) else { return nil }

        let file = destination(for: key(for: location), in: settings, repo: repo)
        return defaultScriptPath(for: location, local: file.hasSuffix(".local.toml"))
    }

    static func writeScript(_ script: String, to path: String, repo: String) throws {
        let full = SettingsLoader.resolve(path, repo: repo)
        prepareFolder(for: full, repo: repo)
        try FileManager.default.createDirectory(
            atPath: (full as NSString).deletingLastPathComponent, withIntermediateDirectories: true
        )

        var text = script
        if !text.hasSuffix("\n") { text += "\n" }
        try text.write(toFile: full, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: full)
    }

    private static func scriptFiles(
        for edits: [SettingsEdit], repo: String, settings: RepoSettings
    ) throws -> [SettingsKey: String] {
        var result: [SettingsKey: String] = [:]
        for edit in edits {
            let location: ScriptLocation
            let script: String
            switch edit {
            case .setupScript(let text): location = .setup; script = text ?? ""
            case .archiveScript(let text): location = .archive; script = text ?? ""
            default: continue
            }
            guard let path = scriptFile(for: location, script: script, in: settings, repo: repo)
            else { continue }
            try writeScript(script, to: path, repo: repo)
            result[edit.key] = path
        }
        return result
    }

    private static func runScriptFiles(
        for edits: [SettingsEdit], repo: String, settings: RepoSettings
    ) throws -> [String: String] {
        var result: [String: String] = [:]
        for case .runScripts(let scripts) in edits {
            for script in scripts {
                guard let path = scriptFile(
                    for: .run(script.id), script: script.command, in: settings, repo: repo
                ) else { continue }
                try writeScript(script.command, to: path, repo: repo)
                result[script.id] = path
            }
        }
        return result
    }

    @discardableResult
    public static func write(
        _ edits: [SettingsEdit],
        repo: String,
        settings: RepoSettings
    ) throws -> [String] {
        let scripts = try scriptFiles(for: edits, repo: repo, settings: settings)
        let runFiles = try runScriptFiles(for: edits, repo: repo, settings: settings)

        var byFile: [String: [SettingsEdit]] = [:]
        for edit in edits {
            byFile[destination(for: edit.key, in: settings, repo: repo), default: []].append(edit)
        }

        var written: [String] = []
        for (path, fileEdits) in byFile.sorted(by: { $0.key < $1.key }) {
            var document = SettingsDocument(contentsOf: path)
            let before = document.text
            for edit in fileEdits {
                let overriding = overrides(edit.key, in: settings, file: path)
                apply(
                    edit,
                    to: &document,
                    overriding: overriding,
                    scriptFile: scripts[edit.key],
                    runFiles: runFiles,
                    runScriptsInFile: overriding ? [] : settings.runScripts,
                    keepingRunScripts: skippedRunScripts(in: settings, file: path)
                )
            }
            guard document.text != before else { continue }
            if !document.exists, document.isEmpty { continue }
            prepareFolder(for: path, repo: repo)
            try document.write(to: path)
            written.append(path)
        }
        return written
    }

    private static func skippedRunScripts(in settings: RepoSettings, file: String) -> Set<String> {
        let loaded = Set(settings.runScripts.map(\.id))
        return Set(settings.issues.compactMap { issue -> String? in
            guard issue.path == file, case let .runScript(id) = issue.entry, !loaded.contains(id)
            else { return nil }
            return id
        })
    }

    private static func overrides(_ key: SettingsKey, in settings: RepoSettings, file: String) -> Bool {
        guard let origin = settings.origins[key] else { return false }
        return origin != file
    }

    static func apply(
        _ edit: SettingsEdit, to document: inout SettingsDocument, overriding: Bool = false,
        scriptFile: String? = nil, runFiles: [String: String] = [:],
        runScriptsInFile: [RunScript] = [], keepingRunScripts: Set<String> = []
    ) {
        switch edit {
        case .setupScript(let script):
            setScript(
                script, inline: SettingsKey.setupScript.path, file: Self.setupFilePath,
                pointingAt: scriptFile, in: &document, overriding: overriding
            )
        case .archiveScript(let script):
            setScript(
                script, inline: SettingsKey.archiveScript.path, file: Self.archiveFilePath,
                pointingAt: scriptFile, in: &document, overriding: overriding
            )
        case .runMode(let mode):
            document.set(.string(mode), at: SettingsKey.runMode.path)
        case .branchPrefix(let prefix):
            set(prefix, at: SettingsKey.branchPrefix.path, in: &document, overriding: overriding)
        case .browserURL(let url):
            set(url, at: SettingsKey.browserURL.path, in: &document, overriding: overriding)
        case .deleteBranchOnArchive(let flag):
            document.set(.boolean(flag), at: SettingsKey.deleteBranchOnArchive.path)
        case .filesToCopy(let globs):
            for legacy in ["files_to_copy", "filesToCopy"] {
                document.remove(at: [legacy])
            }
            document.remove(at: ["files", "copy"])
            document.set(.strings(globs), at: SettingsKey.filesToCopy.path)
        case .runScripts(let scripts):
            writeRunScripts(
                scripts, to: &document, files: runFiles, before: runScriptsInFile,
                keeping: keepingRunScripts
            )
        case .mergeInstructions(let text):
            set(text, at: SettingsKey.mergeInstructions.path, in: &document, overriding: overriding)
        case .conflictInstructions(let text):
            set(
                text, at: SettingsKey.conflictInstructions.path, in: &document,
                overriding: overriding
            )
        }
    }

    static let setupFilePath = ["scripts", "setup_file"]
    static let archiveFilePath = ["scripts", "archive_file"]

    private static func setScript(
        _ value: String?, inline: [String], file: [String], pointingAt path: String?,
        in document: inout SettingsDocument, overriding: Bool
    ) {
        if let path {
            document.remove(at: inline)
            document.set(.string(path), at: file)
            return
        }
        document.remove(at: file)
        set(value, at: inline, in: &document, overriding: overriding)
    }

    private static func set(
        _ value: String?, at path: [String], in document: inout SettingsDocument,
        overriding: Bool = false
    ) {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let trimmed, !trimmed.isEmpty {
            document.set(.string(trimmed), at: path)
        } else if overriding {
            document.set(.string(""), at: path)
        } else {
            document.remove(at: path)
        }
    }

    private static func writeRunScripts(
        _ scripts: [RunScript], to document: inout SettingsDocument, files: [String: String] = [:],
        before: [RunScript] = [], keeping: Set<String> = []
    ) {
        document.remove(at: SettingsKey.runScripts.path)

        let wanted = Set(scripts.map(\.id)).union(keeping)
        let previous = Dictionary(before.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        for table in document.tables(under: ["scripts", "run"]) {
            guard let id = table.last, !wanted.contains(id) else { continue }
            document.removeTable(at: table)
        }

        for script in scripts {
            let base = SettingsKey.runScripts.path + [script.id]
            if let path = files[script.id] {
                document.remove(at: base + ["command"])
                document.set(.string(path), at: base + ["file"])
            } else {
                document.remove(at: base + ["file"])
                document.set(.string(script.command), at: base + ["command"])
            }
            if script.name == script.id.capitalizedFirst {
                document.remove(at: base + ["name"])
            } else {
                document.set(.string(script.name), at: base + ["name"])
            }
            if previous[script.id]?.icon != script.icon || previous[script.id] == nil {
                if let icon = script.icon {
                    document.set(.string(icon), at: base + ["icon"])
                } else {
                    document.remove(at: base + ["icon"])
                }
            }
            if previous[script.id]?.autostart != script.autostart || previous[script.id] == nil {
                if script.autostart {
                    document.set(.boolean(true), at: base + ["autostart"])
                } else {
                    document.remove(at: base + ["autostart"])
                }
            }
        }
    }
}
