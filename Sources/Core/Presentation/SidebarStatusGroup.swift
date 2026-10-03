import Foundation

public enum SidebarStatusGroup: String, CaseIterable, Sendable, Hashable {
    case needsYou
    case readyToRead
    case working
    case idle

    public static let foldThreshold = 4

    public static func of(_ status: WorkspaceStatus) -> SidebarStatusGroup {
        switch status {
        case .awaitingPermission, .setupFailed: .needsYou
        case .unread: .readyToRead
        case .running, .settingUp: .working
        case .merged, .closed, .conflicted, .checksFailing, .checksRunning, .checksPassed, .draft,
             .pullRequestOpen, .changed, .clean:
            .idle
        }
    }

    public static func of(_ status: WorkspaceStatus, unread: Bool) -> SidebarStatusGroup {
        let group = of(status)
        return group == .idle && unread ? .readyToRead : group
    }

    public var title: String {
        switch self {
        case .needsYou: "Needs you"
        case .readyToRead: "Ready to read"
        case .working: "Working"
        case .idle: "Idle"
        }
    }

    public var ranksByRecency: Bool { self == .idle }

    public func canFold(count: Int) -> Bool {
        self == .idle && count >= Self.foldThreshold
    }
}
