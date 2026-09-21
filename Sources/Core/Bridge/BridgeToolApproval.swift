import Foundation

public enum BridgeToolApproval {
    public static var toolPrefix: String { "mcp__\(BridgeRegistration.serverName)__" }

    public static let selfApproved: Set<String> = [
        "whoami",
        "workspace_start",
        "pane_open",
        "pane_split",
        "pane_close",
        "pane_rename",
        "workspace_rename",
        "project_list",
        "quick_prompt_list",
        "pane_list",
        "browser_read",
        "agent_start",
        "agent_say",
        "agent_list",
        "agent_stop",
        "media_show",
        "workspace_tabs",
        "chat_list",
        "chat_read",
        "workspace_diff",
        "workspace_tab_select",
        "reveal",
        "workspace_say",
        "work_suggest",
        "work_withdraw",
    ]

    public static func isSelfApproved(toolName: String) -> Bool {
        guard toolName.hasPrefix(toolPrefix) else { return false }
        return selfApproved.contains(String(toolName.dropFirst(toolPrefix.count)))
    }
}
