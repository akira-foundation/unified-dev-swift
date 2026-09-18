import Foundation

public enum WorkspaceStartPlan {
    public static func name(
        supplied: String?, checkout: WorkspaceCheckout?, prompt: String
    ) -> String {
        if let supplied, !supplied.isEmpty { return supplied }
        if let checkout { return checkout.workspaceName }
        return Git.title(from: prompt)
    }

    public static func terminalName(userSuppliedBranch: String?, claimedSea: String?) -> String? {
        if let userSuppliedBranch, !userSuppliedBranch.isEmpty { return userSuppliedBranch }
        return claimedSea
    }

    public static func unnamedName(
        isChatWorkspace: Bool, hasTask: Bool, userSuppliedBranch: String?, claimedSea: String?
    ) -> String? {
        guard isChatWorkspace else {
            return terminalName(userSuppliedBranch: userSuppliedBranch, claimedSea: claimedSea)
        }
        return hasTask ? nil : claimedSea
    }
}
