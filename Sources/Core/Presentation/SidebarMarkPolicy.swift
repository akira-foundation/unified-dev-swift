import Foundation

public enum SidebarMarkPolicy {
    public static func saysSomething(_ status: WorkspaceStatus) -> Bool {
        switch status {
        case .clean, .changed: false
        case .settingUp, .awaitingPermission, .running, .setupFailed, .unread, .merged, .closed,
             .conflicted, .checksFailing, .checksRunning, .checksPassed, .draft, .pullRequestOpen:
            true
        }
    }

    public static let silent: [WorkspaceStatus] = WorkspaceStatus.allCases.filter { !saysSomething($0) }

    public static let drawn: [WorkspaceStatus] = WorkspaceStatus.allCases.filter(saysSomething)

    public static let drawnInTheWorkspace: [WorkspaceStatus] = drawn.filter { !$0.describesPullRequest }

    public static let drawnOnGitHub: [WorkspaceStatus] = drawn.filter(\.describesPullRequest)
}
