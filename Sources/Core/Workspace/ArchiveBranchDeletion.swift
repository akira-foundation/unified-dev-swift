public enum ArchiveBranchDeletion {
    public static func applies(
        requested: Bool?, settings: RepoSettings, workspace: Workspace, defaultBranch: String
    ) -> Bool {
        guard workspace.branch != defaultBranch, workspace.branch != workspace.baseBranch else { return false }
        return requested ?? settings.deleteBranchOnArchive
    }

    public static func acceptedLoss(force: Bool, tipUnchanged: Bool, lostAtStart: Int?) -> Int {
        guard force, tipUnchanged else { return 0 }
        return lostAtStart ?? 0
    }

    public static func forcesDeletion(lostNow: Int?, acceptedLoss: Int) -> Bool {
        guard let lostNow else { return false }
        return lostNow <= acceptedLoss
    }
}
