import Foundation

public enum SidebarRoleMark {
    public static let orchestrator = "point.3.connected.trianglepath.dotted"

    public static func symbol(isOrchestrator: Bool, status: WorkspaceStatus) -> String? {
        guard isOrchestrator else { return nil }
        switch status {
        case .running, .awaitingPermission, .settingUp, .setupFailed:
            return nil
        case .clean, .changed, .unread, .merged, .closed, .conflicted, .checksFailing, .checksRunning,
             .checksPassed, .draft, .pullRequestOpen:
            return orchestrator
        }
    }
}
