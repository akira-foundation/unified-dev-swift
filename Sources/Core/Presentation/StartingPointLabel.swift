import Foundation

public enum WorkspaceDraftAction: String, Sendable {
    case create
    case open

    public var title: String {
        switch self {
        case .create: "Create"
        case .open: "Open"
        }
    }
}

public enum StartingPointLabel {
    public static let accessibilityLabel = "Starting point"

    public static func text(for point: WorkspaceStartingPoint, remote: String?) -> String {
        switch point {
        case .newBranch(let base): "from " + qualified(base, remote: remote)
        case .existingBranch(let branch): "on \(branch.name)"
        case .pullRequest(let request): "PR #\(request.number)"
        }
    }

    public static func spoken(for point: WorkspaceStartingPoint, remote: String?) -> String {
        switch point {
        case .newBranch(let base): "new branch from " + qualified(base, remote: remote)
        case .existingBranch(let branch): "existing branch \(branch.name)"
        case .pullRequest(let request): "pull request #\(request.number), \(request.title)"
        }
    }

    public static func explanation(for point: WorkspaceStartingPoint, remote: String?) -> String {
        switch point {
        case .newBranch(let base):
            "Create cuts a new branch from \(qualified(base, remote: remote)) into a worktree of its own."
                + " Nothing is written to disk before then."
        case .existingBranch(let branch):
            "Open checks out \(branch.name) into a worktree of its own, and new commits land on it."
        case .pullRequest(let request):
            "Open checks out pull request #\(request.number) into a worktree of its own, to review or carry on."
        }
    }

    public static func glyph(for point: WorkspaceStartingPoint) -> String {
        switch point {
        case .newBranch: "plus.circle"
        case .existingBranch: "arrow.triangle.branch"
        case .pullRequest: "arrow.triangle.pull"
        }
    }

    public static func action(for point: WorkspaceStartingPoint) -> WorkspaceDraftAction {
        guard case .newBranch = point else { return .open }
        return .create
    }

    private static func qualified(_ base: String, remote: String?) -> String {
        remote.map { "\($0)/\(base)" } ?? base
    }
}
