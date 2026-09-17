import Foundation

public enum WorkspaceStatus: String, Sendable, Hashable, CaseIterable, Codable {
    case settingUp
    case awaitingPermission
    case running
    case setupFailed
    case unread
    case merged
    case closed
    case conflicted
    case checksFailing
    case checksRunning
    case checksPassed
    case draft
    case pullRequestOpen
    case changed
    case clean

    public static func resolve(
        workspace: Workspace,
        isRunning: Bool,
        pullRequest: PullRequest?,
        isAwaitingPermission: Bool = false
    ) -> WorkspaceStatus {
        if workspace.setupState == .running { return .settingUp }
        if isAwaitingPermission { return .awaitingPermission }
        if isRunning { return .running }
        if workspace.setupState == .failed { return .setupFailed }
        let branch = ofBranch(workspace: workspace, pullRequest: pullRequest)
        if branch.describesPullRequest { return branch }
        if workspace.unread { return .unread }
        return branch
    }

    public static func ofBranch(
        workspace: Workspace,
        pullRequest: PullRequest?
    ) -> WorkspaceStatus {
        if let pullRequest {
            if pullRequest.isMerged { return .merged }
            if pullRequest.isClosed { return .closed }
            if pullRequest.hasConflicts { return .conflicted }
            if pullRequest.isDraft { return .draft }
            switch pullRequest.checks {
            case .failing: return .checksFailing
            case .pending: return .checksRunning
            case .passing: return .checksPassed
            case .none, .unavailable: return .pullRequestOpen
            }
        }

        return workspace.hasDiff ? .changed : .clean
    }

    public var label: String {
        switch self {
        case .settingUp: "Setting up"
        case .awaitingPermission: "Waiting on you"
        case .running: "Agent running"
        case .setupFailed: "Setup failed"
        case .unread: "Unread"
        case .merged: "Merged"
        case .closed: "Pull request closed"
        case .conflicted: "Merge conflicts"
        case .checksFailing: "Checks failing"
        case .checksRunning: "Checks running"
        case .checksPassed: "Checks passed"
        case .draft: "Draft pull request"
        case .pullRequestOpen: "Pull request open"
        case .changed: "Has changes"
        case .clean: "No changes"
        }
    }

    public var describesPullRequest: Bool {
        switch self {
        case .merged, .closed, .conflicted, .checksFailing, .checksRunning, .checksPassed, .draft,
             .pullRequestOpen:
            true
        case .settingUp, .awaitingPermission, .running, .setupFailed, .unread, .changed, .clean:
            false
        }
    }

    public var needsAnswer: Bool { self == .awaitingPermission }

    public func summary(pullRequest: PullRequest?) -> String {
        if self == .awaitingPermission {
            return "The agent is asking for permission and cannot go on until you answer."
        }
        guard describesPullRequest, let pullRequest else { return label }

        var text = "\(label), pull request #\(pullRequest.number)"
        if let detail = detail(pullRequest: pullRequest) { text += ": \(detail)" }
        return text
    }

    public func detail(pullRequest: PullRequest?) -> String? {
        guard describesPullRequest, let pullRequest else { return nil }
        if self == .conflicted { return pullRequest.status.detail }
        let detail = pullRequest.checksSummary
        guard !detail.isEmpty, detail != label else { return nil }
        return detail
    }
}
