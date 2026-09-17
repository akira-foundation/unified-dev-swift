import Foundation

public struct DraftRunScript: Identifiable, Sendable, Hashable {
    public let id: UUID
    public var key: String
    public var name: String
    public var command: String
    public var icon: String?
    public var autostart: Bool

    public init(
        id: UUID = UUID(), key: String = "", name: String = "", command: String = "",
        icon: String? = nil, autostart: Bool = false
    ) {
        self.id = id
        self.key = key
        self.name = name
        self.command = command
        self.icon = icon
        self.autostart = autostart
    }
}

public struct RepoSettingsDraft: Sendable, Hashable {
    public var setupScript = ""
    public var archiveScript = ""
    public var filesToCopyText = ""
    public var runScripts: [DraftRunScript] = []
    public var runMode = "nonconcurrent"
    public var branchPrefix = ""
    public var deleteBranchOnArchive = false
    public var mergeInstructions = ""
    public var conflictInstructions = ""
    public var browserURL = ""
    public var reservedRunScriptKeys: Set<String> = []

    public init() {}

    public init(_ settings: RepoSettings) {
        setupScript = settings.setupScript ?? ""
        archiveScript = settings.archiveScript ?? ""
        filesToCopyText = settings.filesToCopy.joined(separator: "\n")
        runScripts = settings.runScripts.map {
            DraftRunScript(
                key: $0.id, name: $0.name, command: $0.command, icon: $0.icon, autostart: $0.autostart
            )
        }
        reservedRunScriptKeys = Set(settings.issues.compactMap {
            guard case .runScript(let key) = $0.entry else { return nil }
            return key
        })
        runMode = settings.runMode
        branchPrefix = settings.branchPrefix ?? ""
        deleteBranchOnArchive = settings.deleteBranchOnArchive
        mergeInstructions = settings.mergeInstructions ?? ""
        conflictInstructions = settings.conflictInstructions ?? ""
        browserURL = settings.browserURL ?? ""
    }

    public func runScript(id: DraftRunScript.ID) -> DraftRunScript? {
        runScripts.first { $0.id == id }
    }

    public mutating func updateRunScript(_ script: DraftRunScript) {
        guard let index = runScripts.firstIndex(where: { $0.id == script.id }) else { return }
        runScripts[index] = script
    }

    public mutating func removeRunScript(id: DraftRunScript.ID) {
        runScripts.removeAll { $0.id == id }
    }

    public var globs: [String] {
        filesToCopyText
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    public var resolvedRunScripts: [RunScript] {
        var used = Set(runScripts.map(\.key).filter { !$0.isEmpty }).union(reservedRunScriptKeys)
        return runScripts.compactMap { script in
            let command = script.command.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !command.isEmpty else { return nil }
            var key = script.key
            if key.isEmpty {
                key = Self.uniqueKey(from: script.name, avoiding: used)
                used.insert(key)
            }
            let name = script.name.trimmingCharacters(in: .whitespaces)
            return RunScript(
                id: key, name: name.isEmpty ? key.capitalizedFirst : name, command: command,
                icon: script.icon, autostart: script.autostart
            )
        }
    }

    public static func uniqueKey(from name: String, avoiding used: Set<String>) -> String {
        let slug = name
            .lowercased()
            .map { $0.isLetter || $0.isNumber ? $0 : "-" }
            .reduce(into: "") { result, character in
                if character == "-", result.isEmpty || result.hasSuffix("-") { return }
                result.append(character)
            }
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))

        let base = slug.isEmpty ? "run" : slug
        guard used.contains(base) else { return base }
        var index = 2
        while used.contains("\(base)-\(index)") { index += 1 }
        return "\(base)-\(index)"
    }

    public func edits(comparedTo settings: RepoSettings) -> [SettingsEdit] {
        var edits: [SettingsEdit] = []

        let setup = setupScript.trimmed
        if setup != (settings.setupScript ?? "").trimmed {
            edits.append(.setupScript(setup))
        }
        let archive = archiveScript.trimmed
        if archive != (settings.archiveScript ?? "").trimmed {
            edits.append(.archiveScript(archive))
        }
        if globs != settings.filesToCopy {
            edits.append(.filesToCopy(globs))
        }
        if resolvedRunScripts != settings.runScripts {
            edits.append(.runScripts(resolvedRunScripts))
        }
        if runMode != settings.runMode {
            edits.append(.runMode(runMode))
        }
        let prefix = branchPrefix.trimmingCharacters(in: .whitespaces)
        if prefix != (settings.branchPrefix ?? "") {
            edits.append(.branchPrefix(prefix))
        }
        if deleteBranchOnArchive != settings.deleteBranchOnArchive {
            edits.append(.deleteBranchOnArchive(deleteBranchOnArchive))
        }
        let merge = mergeInstructions.trimmed
        if merge != (settings.mergeInstructions ?? "").trimmed {
            edits.append(.mergeInstructions(merge))
        }
        let conflicts = conflictInstructions.trimmed
        if conflicts != (settings.conflictInstructions ?? "").trimmed {
            edits.append(.conflictInstructions(conflicts))
        }
        let url = browserURL.trimmed
        if url != (settings.browserURL ?? "") {
            edits.append(.browserURL(url))
        }
        return edits
    }
}

private extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
