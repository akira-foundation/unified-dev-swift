import Foundation

public struct BranchActionAvailability: Sendable, Hashable {
    public var isAllowed: Bool

    public var note: String?

    public var reason: String?

    public init(isAllowed: Bool, note: String? = nil, reason: String? = nil) {
        self.isAllowed = isAllowed
        self.note = note
        self.reason = reason
    }

    public static let allowed = BranchActionAvailability(isAllowed: true)

    public static func mayActOnBranch(
        isAgentBusy: Bool,
        pullRequest: PullRequest?
    ) -> BranchActionAvailability {
        guard isAgentBusy, let pullRequest, !pullRequest.isOpen else { return .allowed }
        return BranchActionAvailability(
            isAllowed: false,
            note: "The agent is still running here.",
            reason: "The agent is still running in this worktree. Continue and Archive become "
                + "available when the turn ends."
        )
    }
}
