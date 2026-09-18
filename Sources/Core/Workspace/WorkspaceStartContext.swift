import Foundation

public enum WorkspaceStartContext {
    public static func fetchBranchList(repoPath: String) async -> Bool {
        guard let names = try? await Git.remoteNames(of: repoPath),
              let remote = Git.primaryRemote(of: names)
        else { return false }
        return await BaseBranchFetches.shared.refreshBranches(
            in: repoPath, remote: remote, acceptingWithin: BaseBranchFetches.recent
        )
    }

    static func branchOptions(branches: [String], defaultBranch: String) -> [String] {
        branches.isEmpty ? [defaultBranch] : branches
    }

    static func primaryRemoteBranches(references: [String], remoteNames: [String]) -> [String] {
        guard let primary = Git.primaryRemote(of: remoteNames) else { return [] }
        return references.compactMap { WorkspaceCheckoutPlan.remoteBranchName($0, remote: primary) }
    }

    public static func baseBranchOptions(
        local: [String], remote: [String], defaultBranch: String
    ) -> [String] {
        let names = Set(local + remote).filter { !$0.isEmpty }
        return branchOptions(
            branches: names.sorted { $0.localizedStandardCompare($1) == .orderedAscending },
            defaultBranch: defaultBranch
        )
    }

    public static func prefetch(_ target: BaseBranchPrefetch?) async {
        guard let target else { return }
        await BaseBranchFetches.prefetch(base: target.baseBranch, in: target.repoPath)
    }

    public static func resolvedBaseBranch(
        current: String,
        local: [String],
        remote: [String],
        defaultBranch: String
    ) -> String {
        let options = baseBranchOptions(local: local, remote: remote, defaultBranch: defaultBranch)
        if options.contains(current) { return current }
        if options.contains(defaultBranch) { return defaultBranch }
        return local.first { !$0.isEmpty } ?? options.first ?? defaultBranch
    }
}
