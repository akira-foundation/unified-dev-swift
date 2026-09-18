import Foundation

public struct BaseBranchPrefetch: Hashable, Sendable {
    public let repoPath: String
    public let baseBranch: String

    public init(repoPath: String, baseBranch: String) {
        self.repoPath = repoPath
        self.baseBranch = baseBranch
    }

    public static func target(
        repoPath: String?, baseBranch: String, opensCheckout: Bool
    ) -> BaseBranchPrefetch? {
        guard let repoPath, !opensCheckout, !baseBranch.isEmpty else { return nil }
        return BaseBranchPrefetch(repoPath: repoPath, baseBranch: baseBranch)
    }
}
