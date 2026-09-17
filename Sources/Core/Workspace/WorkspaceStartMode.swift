import Foundation

public enum WorkspaceStartMode: String, CaseIterable, Identifiable, Sendable {
    case chat
    case claudeCLI
    case codexCLI
    case terminal
    case browser

    public static func chat(usesCLI: Bool, agent: AgentKind) -> Self {
        guard usesCLI else { return .chat }
        switch agent {
        case .claudeCode: return .claudeCLI
        case .codex: return .codexCLI
        case .cursor, .openCode, .grok: return .chat
        }
    }

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .chat: "Chat"
        case .claudeCLI: "Claude CLI"
        case .codexCLI: "Codex CLI"
        case .terminal: "Terminal"
        case .browser: "Browser"
        }
    }

    public var pickerLabel: String {
        switch self {
        case .chat: "Chat with an agent"
        case .claudeCLI: "Claude CLI"
        case .codexCLI: "Codex CLI"
        case .terminal: "Terminal"
        case .browser: "Browser"
        }
    }

    public var runsAnAgent: Bool { self == .chat || cliAgentKind != nil }

    public var cliAgentKind: AgentKind? {
        switch self {
        case .claudeCLI: .claudeCode
        case .codexCLI: .codex
        case .chat, .terminal, .browser: nil
        }
    }

    public var pane: PaneKind {
        switch self {
        case .chat, .claudeCLI, .codexCLI: .chat
        case .terminal: .terminal
        case .browser: .browser
        }
    }

    public var openingSentence: String {
        switch self {
        case .chat: "the agent starts on it"
        case .claudeCLI: "Claude opens in a terminal with your task"
        case .codexCLI: "Codex opens in a terminal with your task"
        case .terminal: "a shell opens in the worktree"
        case .browser: "a browser opens beside it"
        }
    }

    public static let rememberedKey = "create.mode"

    public static func remembered(raw: String?) -> WorkspaceStartMode {
        raw.flatMap(WorkspaceStartMode.init(rawValue:)) ?? .chat
    }

    public static func defaultsKey(workspaceID: WorkspaceID) -> String {
        "workspace.opensOn.\(workspaceID)"
    }

    static func legacyTerminalKey(workspaceID: WorkspaceID) -> String {
        "workspace.opensOnTerminal.\(workspaceID)"
    }

    public static func record(
        _ mode: WorkspaceStartMode, workspaceID: WorkspaceID, defaults: UserDefaults = .standard
    ) {
        guard mode != .chat else { return }
        defaults.set(mode.rawValue, forKey: defaultsKey(workspaceID: workspaceID))
    }

    public static func consumeOpeningTab(
        workspaceID: WorkspaceID, defaults: UserDefaults = .standard
    ) -> WorkspaceStartMode? {
        let key = defaultsKey(workspaceID: workspaceID)
        if let raw = defaults.string(forKey: key) {
            defaults.removeObject(forKey: key)
            let recorded = WorkspaceStartMode(rawValue: raw)
            return recorded == .chat ? nil : recorded
        }
        let legacy = legacyTerminalKey(workspaceID: workspaceID)
        guard defaults.bool(forKey: legacy) else { return nil }
        defaults.removeObject(forKey: legacy)
        return .terminal
    }
}
