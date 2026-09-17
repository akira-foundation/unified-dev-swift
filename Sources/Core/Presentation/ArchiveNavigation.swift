import Foundation

public enum ArchiveNavigation {
    public static func destination(
        leaving selection: SidebarSelection, archiving id: WorkspaceID
    ) -> SidebarSelection? {
        guard selection.workspaceID == id else { return nil }
        return .home
    }
}
