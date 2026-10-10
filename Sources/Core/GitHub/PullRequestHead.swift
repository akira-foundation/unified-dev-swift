import Foundation

public enum PullRequestHead {
    public static func branch(recorded: String, checkedOut: String?, base: String) -> String {
        let live = (checkedOut ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !live.isEmpty else { return recorded }
        guard !recorded.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return live }
        return live == base ? recorded : live
    }

    public static func selector(in context: GitRepositoryContext) -> String? {
        let head = context.headBranch.trimmingCharacters(in: .whitespacesAndNewlines)
        guard Git.isValidBranchName(head) else { return nil }
        return label(head, of: context.headRemoteURL, base: context.baseRemoteURL)
    }

    static func label(_ branch: String, of remoteURL: String?, base baseURL: String?) -> String {
        guard let owner = owner(of: remoteURL, otherThan: baseURL) else { return branch }
        return "\(owner):\(branch)"
    }

    static func owner(of remoteURL: String?, otherThan baseURL: String?) -> String? {
        guard let remote = GitHub.repositorySpecifier(remoteURL),
              let base = GitHub.repositorySpecifier(baseURL),
              remote.caseInsensitiveCompare(base) != .orderedSame else { return nil }
        let pieces = remote.split(separator: "/")
        guard pieces.count == 3 else { return nil }
        let owner = String(pieces[1])
        return GitHub.isPlausibleLogin(owner) ? owner : nil
    }
}
