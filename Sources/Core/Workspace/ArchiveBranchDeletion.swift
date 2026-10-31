public enum ArchiveBranchDeletion {
    public static func applies(
        requested: Bool?, settings: RepoSettings, workspace: Workspace, defaultBranch: String
    ) -> Bool {
        guard workspace.branch != defaultBranch, workspace.branch != workspace.baseBranch else { return false }
        return requested ?? settings.deleteBranchOnArchive
    }
}
