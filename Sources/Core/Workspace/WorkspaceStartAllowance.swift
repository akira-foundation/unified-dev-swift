import Foundation

public enum WorkspaceStartAllowance: Sendable, Equatable {
    case unlimited

    case running(limit: Int)

    case rate(limit: Int, window: TimeInterval)

    public static let maximumChildren = 8

    public static let maximumOwnerStarts = 6

    public static let ownerWindow: TimeInterval = 15 * 60

    public static func of(_ origin: WorkspaceOrigin) -> WorkspaceStartAllowance {
        switch origin {
        case .user: .unlimited
        case .agent: .running(limit: maximumChildren)
        case .ownerClient: .rate(limit: maximumOwnerStarts, window: ownerWindow)
        }
    }

    public func isExceeded(by count: Int) -> Bool {
        switch self {
        case .unlimited: false
        case .running(let limit): count >= limit
        case .rate(let limit, _): count >= limit
        }
    }

    public func refusal(count: Int) -> String? {
        guard isExceeded(by: count) else { return nil }

        switch self {
        case .unlimited:
            return nil

        case .running:
            return "You already have \(count) workspaces running, which is Unified Dev's limit. "
                + "Wait for some to be reviewed and archived before starting more."

        case .rate(_, let window):
            let minutes = Int(window / 60)
            return """
                Unified Dev has already started \(count) workspaces for you in the last \(minutes) \
                minutes, which is as many as it will start from a client outside the app. Each one \
                is a real git worktree, a real agent process and real spend, and this many in this \
                short a time is what a misread instruction looks like rather than a plan. Calling \
                again will be refused for the same reason, and nothing you can do here shortens \
                the \(minutes) minutes, so do not retry and do not wait for it. Tell the owner what \
                you have already started and what is left over, and leave the rest to them: \
                Unified Dev's own window starts workspaces with no limit, one deliberate press at a time.
                """
        }
    }
}
