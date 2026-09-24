import Foundation

public struct RunScriptAutostartApproval: Codable, Sendable, Hashable {
    public var commands: [String: [String]]

    public init(commands: [String: [String]] = [:]) {
        self.commands = commands
    }

    static let historyLimit = 8

    public static func key(repoID: RepoID) -> String {
        "runScripts.autostart.approved.\(repoID.rawValue)"
    }

    public func approves(_ script: RunScript) -> Bool {
        commands[script.id]?.contains(script.command) == true
    }

    public func approving(_ scripts: [RunScript]) -> RunScriptAutostartApproval {
        var next = self
        for script in scripts {
            var history = next.commands[script.id, default: []]
            history.removeAll { $0 == script.command }
            history.append(script.command)
            next.commands[script.id] = Array(history.suffix(Self.historyLimit))
        }
        return next
    }

    public static func load(repoID: RepoID, from store: Store) async -> RunScriptAutostartApproval? {
        guard let raw = try? await store.setting(key(repoID: repoID)),
              let data = raw.data(using: .utf8)
        else { return nil }
        return try? JSONDecoder().decode(RunScriptAutostartApproval.self, from: data)
    }

    public func save(repoID: RepoID, to store: Store) async throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let data = try encoder.encode(self)
        try await store.setSetting(Self.key(repoID: repoID), String(decoding: data, as: UTF8.self))
    }
}

public enum RunScriptAutostart: Sendable, Hashable {
    case nothing
    case run([RunScript])
    case ask(scripts: [RunScript], changes: [Change])

    public struct Change: Sendable, Hashable {
        public var script: RunScript
        public var approved: String?

        public init(script: RunScript, approved: String?) {
            self.script = script
            self.approved = approved
        }
    }

    public static func decide(
        scripts: [RunScript], approval: RunScriptAutostartApproval?
    ) -> RunScriptAutostart {
        let candidates = candidates(in: scripts)
        guard !candidates.isEmpty else { return .nothing }

        guard let approval else { return .ask(scripts: candidates, changes: []) }
        let unapproved = candidates.filter { !approval.approves($0) }
        guard !unapproved.isEmpty else { return .run(candidates) }
        return .ask(
            scripts: candidates,
            changes: unapproved.map { Change(script: $0, approved: approval.commands[$0.id]?.last) }
        )
    }

    public static func signature(of scripts: [RunScript]) -> [String] {
        candidates(in: scripts).map(entry(of:))
    }

    public static func entry(of script: RunScript) -> String {
        "\(script.id)\u{1F}\(script.command)"
    }

    private static func candidates(in scripts: [RunScript]) -> [RunScript] {
        scripts.filter {
            $0.autostart && !$0.command.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }
}

extension RunScriptAutostart {
    public static func isTimely(isRunningSetup: Bool, setupState: SetupState, hasSetupScript: Bool) -> Bool {
        if isRunningSetup { return false }
        switch setupState {
        case .running: return false
        case .pending: return !hasSetupScript
        case .succeeded, .failed, .ignored, .skipped: return true
        }
    }
}
