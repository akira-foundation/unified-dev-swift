import Foundation

public enum DockBadge {
    public static let settingKey = "dock.badgesUnread"

    public static func unreadCount(
        in workspaces: [Workspace],
        isRunning: (Workspace) -> Bool
    ) -> Int {
        workspaces.count { hasUnreadResult($0, isRunning: isRunning) }
    }

    public static func hasUnreadResult(
        _ workspace: Workspace,
        isRunning: (Workspace) -> Bool
    ) -> Bool {
        workspace.unread && !isRunning(workspace)
    }

    public static func waitingCount(
        in workspaces: [Workspace],
        isAwaitingPermission: (Workspace) -> Bool
    ) -> Int {
        workspaces.count(where: isAwaitingPermission)
    }

    public static func label(unread: Int, waiting: Int = 0, isEnabled: Bool) -> String? {
        guard isEnabled else { return nil }
        if waiting > 0 { return String(waiting) }
        guard unread > 0 else { return nil }
        return String(unread)
    }
}
