import Foundation

public enum PullRequestHead {
    public static func branch(recorded: String, checkedOut: String?, base: String) -> String {
        let live = (checkedOut ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !live.isEmpty else { return recorded }
        guard !recorded.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return live }
        return live == base ? recorded : live
    }

    public static func selector(in context: GitRepositoryContext) -> String? {
        let head = branch(in: context)
        guard Git.isValidBranchName(head) else { return nil }
        guard let owner = owner(of: context.headRemoteURL, otherThan: context.baseRemoteURL) else {
            return Int(head) == nil ? head : nil
        }
        return "\(owner):\(head)"
    }

    public static func branch(in context: GitRepositoryContext) -> String {
        let head = context.headBranch.trimmingCharacters(in: .whitespacesAndNewlines)
        guard head != context.publishBranch else { return head }
        guard owner(of: context.headRemoteURL, otherThan: context.baseRemoteURL) != nil else {
            return context.publishBranch
        }
        return head
    }

    static func label(_ branch: String, of remoteURL: String?, base baseURL: String?) -> String {
        guard let owner = owner(of: remoteURL, otherThan: baseURL) else { return branch }
        return "\(owner):\(branch)"
    }

    static func owner(of remoteURL: String?, otherThan baseURL: String?) -> String? {
        guard let remote = GitHub.repositorySpecifier(remoteURL),
              let base = GitHub.repositorySpecifier(baseURL),
              remote.caseInsensitiveCompare(base) != .orderedSame,
              reachesTheSameForge(remoteURL, as: baseURL) else { return nil }
        return owner(ofRepository: remoteURL)
    }

    static func reachesTheSameForge(_ remoteURL: String?, as baseURL: String?) -> Bool {
        guard let host = GitHub.repositoryHost(remoteURL) else { return false }
        return host == GitHub.repositoryHost(baseURL)
    }

    static func owner(ofRepository remoteURL: String?) -> String? {
        guard let specifier = GitHub.repositorySpecifier(remoteURL) else { return nil }
        let pieces = specifier.split(separator: "/")
        guard pieces.count == 3 else { return nil }
        let owner = String(pieces[1])
        return GitHub.isPlausibleLogin(owner) ? owner : nil
    }
}
