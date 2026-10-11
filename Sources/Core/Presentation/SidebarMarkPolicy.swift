import Foundation

public enum SidebarMarkPolicy {
    public static let silent: Set<WorkspaceStatus> = [.clean, .changed]

    public static func saysSomething(_ status: WorkspaceStatus) -> Bool {
        !silent.contains(status)
    }
}
