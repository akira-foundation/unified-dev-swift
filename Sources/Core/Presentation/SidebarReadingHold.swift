import Foundation

public enum SidebarReadingHold {
    public static func next(
        selection: SidebarSelection,
        current: WorkspaceID?,
        workspaces: [Workspace]
    ) -> WorkspaceID? {
        guard let id = selection.workspaceID else { return nil }
        if id == current { return current }
        guard case .workspace = selection else { return nil }
        let unread = workspaces.first { $0.id == id }.map(WorkspaceUnreadMark.isUnread) ?? false
        return unread ? id : nil
    }
}
