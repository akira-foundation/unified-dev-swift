public struct ArchiveKeptBranch: Sendable, Equatable {
    public var branch: String
    public var commitsNowhereElse: Int?

    public init(branch: String, commitsNowhereElse: Int?) {
        self.branch = branch
        self.commitsNowhereElse = commitsNowhereElse
    }

    public var sentence: String {
        guard let commitsNowhereElse, commitsNowhereElse > 0 else {
            return "Its branch `\(branch)` could not be deleted and is still there."
        }
        let commits = commitsNowhereElse == 1 ? "1 commit on it exists" : "\(commitsNowhereElse) commits on it exist"
        return "Its branch `\(branch)` was not deleted, because \(commits) on no other branch, tag or remote."
    }
}
