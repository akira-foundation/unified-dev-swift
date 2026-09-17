import Foundation
import Synchronization

public struct RunScript: Identifiable, Sendable, Hashable {
    public var id: String
    public var name: String
    public var command: String
    public var icon: String?
    public var autostart: Bool

    public init(
        id: String, name: String, command: String, icon: String? = nil, autostart: Bool = false
    ) {
        self.id = id
        self.name = name
        self.command = command
        self.icon = icon
        self.autostart = autostart
    }
}

public enum SettingsKey: String, Sendable, Hashable, CaseIterable {
    case setupScript = "scripts.setup"
    case archiveScript = "scripts.archive"
    case runScripts = "scripts.run"
    case runMode = "scripts.run_mode"
    case filesToCopy = "file_include_globs"
    case branchPrefix = "git.branch_prefix"
    case deleteBranchOnArchive = "git.delete_branch_on_archive"
    case mergeInstructions = "instructions.merge"
    case conflictInstructions = "instructions.fix_conflicts"
    case browserURL = "browser.url"

    public var path: [String] { rawValue.components(separatedBy: ".") }
}

public enum ScriptLocation: Sendable, Hashable {
    case setup
    case archive
    case run(String)
}

public struct ScriptFile: Sendable, Hashable {
    public var path: String
    public var isMissing: Bool

    public init(path: String, isMissing: Bool) {
        self.path = path
        self.isMissing = isMissing
    }
}

public struct RepoSettings: Sendable, Hashable {
    public var setupScript: String?
    public var archiveScript: String?
    public var runScripts: [RunScript] = []
    public var runMode: String = "nonconcurrent"
    public var filesToCopy: [String] = [".env*"]
    public var branchPrefix: String?
    public var deleteBranchOnArchive: Bool = false
    public var mergeInstructions: String?
    public var conflictInstructions: String?
    public var browserURL: String?
    public var defaultModel: String?
    public var defaultEffort: String?
    public var homeDefaultModel: String?
    public var homeDefaultEffort: String?
    public var scriptFiles: [ScriptLocation: ScriptFile] = [:]
    public var sources: [String] = []

    public var origins: [SettingsKey: String] = [:]

    public var quickPrompts: [ProjectQuickPrompt] = []

    public var issues: [SettingsIssue] = []

    public init() {}
}

public enum SettingsLoader {
    public static func homePaths() -> [String] {
        let home = NSHomeDirectory()
        return [
            "\(home)/.conductor/settings.toml",
            "\(home)/.unifieddev/settings.toml",
        ]
    }

    public static func repoPaths(repo: String) -> [String] {
        [
            "\(repo)/.conductor/settings.toml",
            "\(repo)/.unifieddev/settings.toml",
            "\(repo)/.conductor/settings.local.toml",
            "\(repo)/.unifieddev/settings.local.toml",
        ]
    }

    public static func candidatePaths(repo: String) -> [String] {
        homePaths() + repoPaths(repo: repo)
    }

    public static func load(repo: String) -> RepoSettings {
        var settings = RepoSettings()

        for path in homePaths() {
            guard let document = read(path, into: &settings) else { continue }
            settings.sources.append(path)
            apply(document.value, outline: document.outline, from: path, to: &settings, repo: repo)
        }

        settings.homeDefaultModel = settings.defaultModel
        settings.homeDefaultEffort = settings.defaultEffort
        settings.defaultModel = nil
        settings.defaultEffort = nil

        for path in repoPaths(repo: repo) {
            guard let document = read(path, into: &settings) else { continue }
            settings.sources.append(path)
            apply(document.value, outline: document.outline, from: path, to: &settings, repo: repo)
            applyQuickPrompts(document.value, outline: document.outline, from: path, to: &settings)
        }

        return settings
    }

    private static func read(_ path: String, into settings: inout RepoSettings) -> TOMLDocument? {
        do {
            return try TOML.parseOutlined(contentsOf: path)
        } catch let error as TOMLError {
            settings.issues.append(SettingsIssue(
                path: path,
                message: "This file was skipped: line \(error.line) could not be read (\(error.message)).",
                entry: .file,
                line: error.line
            ))
            return nil
        } catch {
            settings.issues.append(SettingsIssue(
                path: path,
                message: "This file was skipped: it could not be read.",
                entry: .file
            ))
            return nil
        }
    }

    public static func resolve(_ path: String, repo: String) -> String {
        if path.hasPrefix("/") { return path }
        if path.hasPrefix("~") { return (path as NSString).expandingTildeInPath }
        return (repo as NSString).appendingPathComponent(path)
    }

    private static func readScript(
        _ toml: TOMLValue, inline: String, file: String, repo: String
    ) -> (text: String?, file: ScriptFile?)? {
        if let stated = toml[file]?.stringValue, !stated.isEmpty {
            let full = resolve(stated, repo: repo)
            guard let text = try? String(contentsOfFile: full, encoding: .utf8) else {
                return (nil, ScriptFile(path: stated, isMissing: true))
            }
            let hasContent = !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            return (hasContent ? text : nil, ScriptFile(path: stated, isMissing: false))
        }
        guard let text = toml[inline]?.stringValue else { return nil }
        return (text.isEmpty ? nil : text, nil)
    }

    static func apply(
        _ toml: TOMLValue, outline: TOMLOutline? = nil, from source: String,
        to settings: inout RepoSettings, repo: String = ""
    ) {
        func note(_ key: SettingsKey) { settings.origins[key] = source }

        if let setup = readScript(toml, inline: "scripts.setup", file: "scripts.setup_file", repo: repo) {
            settings.setupScript = setup.text
            settings.scriptFiles[.setup] = setup.file
            note(.setupScript)
        }
        if let archive = readScript(toml, inline: "scripts.archive", file: "scripts.archive_file", repo: repo) {
            settings.archiveScript = archive.text
            settings.scriptFiles[.archive] = archive.file
            note(.archiveScript)
        }
        if let mode = toml["scripts.run_mode"]?.stringValue {
            settings.runMode = mode
            note(.runMode)
        }
        if let mode = toml["runScriptMode"]?.stringValue {
            settings.runMode = mode
            note(.runMode)
        }

        if toml["scripts.run"] != nil {
            applyRunScripts(toml, outline: outline, from: source, to: &settings, repo: repo)
        }

        for key in ["file_include_globs", "files_to_copy", "filesToCopy", "files.copy"] {
            if let files = toml[key]?.stringArray {
                settings.filesToCopy = files
                settings.origins[.filesToCopy] = source
            }
        }

        if let prefix = toml["git.branch_prefix"]?.stringValue {
            settings.branchPrefix = prefix
            note(.branchPrefix)
        }
        if let type = toml["git.branch_prefix_type"]?.stringValue {
            switch type {
            case "github_username":
                settings.branchPrefix = GitHubIdentity.cachedUsername
                note(.branchPrefix)
            case "none":
                settings.branchPrefix = nil
                note(.branchPrefix)
            default:
                break
            }
        }
        if let delete = toml["git.delete_branch_on_archive"]?.boolValue {
            settings.deleteBranchOnArchive = delete
            note(.deleteBranchOnArchive)
        }
        if let text = toml["instructions.merge"]?.stringValue {
            settings.mergeInstructions = text.isEmpty ? nil : text
            note(.mergeInstructions)
        }
        if let text = toml["instructions.fix_conflicts"]?.stringValue {
            settings.conflictInstructions = text.isEmpty ? nil : text
            note(.conflictInstructions)
        }
        if let url = toml["browser.url"]?.stringValue {
            settings.browserURL = url.isEmpty ? nil : url
            note(.browserURL)
        }
        if let model = toml["models.default"]?.stringValue {
            settings.defaultModel = model
        }
        if let effort = toml["models.claude.default_thinking_level"]?.stringValue {
            settings.defaultEffort = effort
        }
    }
}

public enum GitHubIdentity {
    private struct Identity {
        var username: String?
        var resolved = false
    }

    private static let state = Mutex(Identity())

    public static var cachedUsername: String? {
        state.withLock(\.username)
    }

    public static func resolve() async {
        guard !state.withLock(\.resolved) else { return }

        var username: String?
        if let result = try? await Shell.run("gh", ["api", "user", "--jq", ".login"], timeout: .seconds(10)),
           result.ok, !result.trimmed.isEmpty {
            username = result.trimmed
        }
        if username == nil,
           let result = try? await Shell.run("git", ["config", "--get", "github.user"]),
           result.ok, !result.trimmed.isEmpty {
            username = result.trimmed
        }

        state.withLock {
            $0.username = username
            $0.resolved = true
        }
    }
}

public extension String {
    var capitalizedFirst: String {
        isEmpty ? self : prefix(1).uppercased() + dropFirst()
    }
}

public struct AppDefaults: Sendable, Hashable {
    public enum Key {
        public static let model = "defaults.model"
        public static let effort = "defaults.effort"
        public static let backend = "defaults.backend"
        public static let reviewModel = "defaults.review.model"
        public static let reviewEffort = "defaults.review.effort"
        public static let reviewBackend = "defaults.review.backend"
        public static let permissionMode = "defaults.permissionMode"
        public static let terminalChat = "defaults.terminalChat"
        public static let planMode = "defaults.planMode"
        public static let fastMode = "defaults.fastMode"
        public static let outputStyle = "defaults.outputStyle"
        public static let codexContextWindow = "defaults.codex.contextWindow"
    }

    public static let fallbackModel = "opus"
    public static let fallbackEffort = "high"
    public static let fallbackBackend = AgentKind.claudeCode
    public static let fallbackPermissionMode = PermissionMode.bypassPermissions

    public var model: String
    public var effort: String
    public var backend: AgentKind
    public var reviewModel: String
    public var reviewEffort: String
    public var reviewBackend: AgentKind
    public var permissionMode: PermissionMode
    public var terminalChat: Bool = false
    public var planMode: Bool
    public var fastMode: Bool
    public var outputStyle: String
    public var codexContextWindow: Int

    public var storedModel: String?
    public var storedEffort: String?

    public init(
        model: String = AppDefaults.fallbackModel,
        effort: String = AppDefaults.fallbackEffort,
        backend: AgentKind = AppDefaults.fallbackBackend,
        reviewModel: String = AppDefaults.fallbackModel,
        reviewEffort: String = AppDefaults.fallbackEffort,
        reviewBackend: AgentKind = AppDefaults.fallbackBackend,
        permissionMode: PermissionMode = AppDefaults.fallbackPermissionMode,
        planMode: Bool = false,
        fastMode: Bool = false,
        outputStyle: String = OutputStyle.defaultName,
        codexContextWindow: Int = CodexContextWindow.modelDefault
    ) {
        self.model = model
        self.effort = effort
        self.backend = backend
        self.reviewModel = reviewModel
        self.reviewEffort = reviewEffort
        self.reviewBackend = reviewBackend
        self.permissionMode = permissionMode
        self.planMode = planMode
        self.fastMode = fastMode
        self.outputStyle = outputStyle
        self.codexContextWindow = codexContextWindow
    }

    public static func load(from store: Store) async -> AppDefaults {
        func value(_ key: String) async -> String? {
            let raw = try? await store.setting(key)
            guard let raw, !raw.isEmpty else { return nil }
            return raw
        }

        var defaults = AppDefaults()
        defaults.storedModel = await value(Key.model)
        defaults.storedEffort = await value(Key.effort)
        defaults.model = defaults.storedModel ?? fallbackModel
        defaults.effort = defaults.storedEffort ?? fallbackEffort
        defaults.backend = await value(Key.backend).flatMap(AgentKind.init) ?? fallbackBackend
        defaults.reviewModel = await value(Key.reviewModel) ?? defaults.model
        defaults.reviewEffort = await value(Key.reviewEffort) ?? defaults.effort
        defaults.reviewBackend = await value(Key.reviewBackend).flatMap(AgentKind.init)
            ?? defaults.backend
        if let raw = await value(Key.permissionMode), let mode = PermissionMode(rawValue: raw) {
            defaults.permissionMode = mode
        }
        defaults.terminalChat = await value(Key.terminalChat) == "1"
        defaults.planMode = await value(Key.planMode) == "1"
        defaults.fastMode = await value(Key.fastMode) == "1"
        defaults.outputStyle = await value(Key.outputStyle) ?? OutputStyle.defaultName
        defaults.codexContextWindow = CodexContextWindow.normalised(await value(Key.codexContextWindow))
        return defaults
    }

    public func saveChanges(from previous: AppDefaults, to store: Store) async throws {
        let values = storedValues
        let oldValues = previous.storedValues
        var changed = Set(values.keys.filter { values[$0, default: nil] != oldValues[$0, default: nil] })
        let modelKeys: Set<String> = [Key.model, Key.effort, Key.backend]
        let reviewKeys: Set<String> = [Key.reviewModel, Key.reviewEffort, Key.reviewBackend]
        if !changed.isDisjoint(with: modelKeys) {
            changed.formUnion(modelKeys)
            changed.formUnion(reviewKeys)
        } else if !changed.isDisjoint(with: reviewKeys) {
            changed.formUnion(reviewKeys)
        }
        for key in changed.sorted() {
            try await store.setSetting(key, values[key, default: nil])
        }
    }

    private var storedValues: [String: String?] {
        [
            Key.model: model,
            Key.effort: effort,
            Key.backend: backend.rawValue,
            Key.reviewModel: reviewModel,
            Key.reviewEffort: reviewEffort,
            Key.reviewBackend: reviewBackend.rawValue,
            Key.permissionMode: permissionMode.rawValue,
            Key.terminalChat: terminalChat ? "1" : "0",
            Key.planMode: planMode ? "1" : "0",
            Key.fastMode: fastMode ? "1" : "0",
            Key.outputStyle: OutputStyle.isDefault(outputStyle) ? nil : outputStyle,
            Key.codexContextWindow: CodexContextWindow.stored(codexContextWindow),
        ]
    }

    public func save(to store: Store) async {
        try? await store.setSetting(Key.model, model)
        try? await store.setSetting(Key.effort, effort)
        try? await store.setSetting(Key.backend, backend.rawValue)
        try? await store.setSetting(Key.reviewModel, reviewModel)
        try? await store.setSetting(Key.reviewEffort, reviewEffort)
        try? await store.setSetting(Key.reviewBackend, reviewBackend.rawValue)
        try? await store.setSetting(Key.permissionMode, permissionMode.rawValue)
        try? await store.setSetting(Key.terminalChat, terminalChat ? "1" : "0")
        try? await store.setSetting(Key.planMode, planMode ? "1" : "0")
        try? await store.setSetting(Key.fastMode, fastMode ? "1" : "0")
        try? await store.setSetting(
            Key.outputStyle, OutputStyle.isDefault(outputStyle) ? nil : outputStyle
        )
        try? await store.setSetting(
            Key.codexContextWindow, CodexContextWindow.stored(codexContextWindow)
        )
    }
}
