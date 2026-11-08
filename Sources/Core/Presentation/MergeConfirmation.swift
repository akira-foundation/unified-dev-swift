import Foundation

public enum MergeConfirmation {
    public static func canConfirm(
        pullRequest: PullRequest?,
        localWork: LocalWork?,
        branchActions: BranchActionAvailability,
        isWorking: Bool
    ) -> Bool {
        guard let pullRequest, pullRequest.isOpen else { return false }
        return pullRequest.status(local: localWork).canMerge && branchActions.isAllowed && !isWorking
    }
}
