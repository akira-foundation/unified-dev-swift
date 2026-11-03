import Foundation

public enum OrchestratorToolGuard {
    static let readingTools: Set<String> = [
        "Read", "Grep", "Glob", "LS", "WebSearch", "WebFetch", "TodoWrite", "Task", "Agent", "SubAgent",
        "ExitPlanMode", "EnterPlanMode", "Plan", "BashOutput", "KillShell", "ToolSearch", "Skill",
        AgentQuestionnaire.toolName, "UserInput", "McpElicitation",
    ]

    static let shellTools: Set<String> = ["Bash", "Shell"]

    private static let directoryKeys = ["cwd", "workdir", "working_directory", "directory"]

    static let refusedBridgeTools: Set<String> = ["terminal_start", "terminal_write", "terminal_send_key"]

    public static let claudeAskingMode = "default"

    public static let claudePermissions: [String: [String]] = ["ask": ["Bash", "mcp__*"]]

    public static let claudeDisallowedTools: [String] =
        ["Edit", "Write", "MultiEdit", "NotebookEdit"] + OrchestratorShellJudge.gitVerbs.map { "Bash(git \($0):*)" }

    public static func refusal(toolName: String, input: JSONValue) -> String? {
        if shellTools.contains(toolName) {
            let command = input["command"]?.stringValue ?? ""
            return OrchestratorShellJudge.refuses(command) ? refused("running a git command that changes the repository") : nil
        }
        if toolName.hasPrefix(BridgeToolApproval.toolPrefix) {
            let tool = String(toolName.dropFirst(BridgeToolApproval.toolPrefix.count))
            return refusedBridgeTools.contains(tool) ? refused("driving a terminal") : nil
        }
        if toolName.hasPrefix("mcp__") || readingTools.contains(toolName) { return nil }
        return refused("using \(toolName), which can change files")
    }

    static func answersItself(toolName: String, input: JSONValue, worktree: String) -> Bool {
        guard shellTools.contains(toolName), let command = input["command"]?.stringValue,
              directoryKeys.allSatisfy({ runs(in: input[$0], worktree: worktree) }) else { return false }
        return OrchestratorShellJudge.reads(command)
    }

    private static func runs(in directory: JSONValue?, worktree: String) -> Bool {
        guard let directory else { return true }
        guard let path = directory.stringValue else { return false }
        return URL(fileURLWithPath: path).standardized.path == URL(fileURLWithPath: worktree).standardized.path
    }

    public static func terminalRefusal(workspaceID: WorkspaceID, store: Store) async -> String? {
        do {
            guard try await store.workspace(id: workspaceID)?.isOrchestrator == true else { return nil }
        } catch {
            return refused("driving a terminal")
        }
        return refused("driving a terminal")
    }

    public static func appliesStoredApprovals(toolName: String, orchestrates: Bool) -> Bool {
        !orchestrates || readingTools.contains(toolName)
    }

    public static let claudeArguments = [
        "--disallowedTools", claudeDisallowedTools.joined(separator: " "),
        "--append-system-prompt", OrchestratorRole.instructions,
    ]

    public static func claudeMode(_ requested: PermissionMode, orchestrates: Bool) -> String {
        guard orchestrates, requested != .plan else { return requested.cliValue }
        return claudeAskingMode
    }

    public static func permissionMode(_ requested: PermissionMode, orchestrates: Bool) -> PermissionMode {
        orchestrates ? permissionMode(requested) : requested
    }

    public static func permissionMode(_ requested: PermissionMode) -> PermissionMode {
        switch requested {
        case .bypassPermissions, .acceptEdits, .autoReview: .auto
        case .auto, .plan: requested
        }
    }

    public static func prompt(_ text: String, orchestrates: Bool, opensSession: Bool) -> String {
        guard orchestrates, opensSession else { return text }
        return OrchestratorRole.instructions + "\n\n" + text
    }

    private static func refused(_ what: String) -> String {
        "This workspace is the project's orchestrator, and Unified Dev refuses \(what) here. "
            + "Start a workspace with workspace_start for the change and follow it from here."
    }
}
