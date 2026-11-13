import Foundation

public extension GitHub {
    static func branchPullRequests(_ branch: String, worktree: String) async throws -> [BranchPullRequest] {
        guard Git.isValidBranchName(branch) else { return [] }
        let context = try? await Git.repositoryContext(in: worktree, branch: branch, baseIsBranchName: true)
        let arguments = [
            "pr", "list", "--head", branch, "--state", "all", "--limit", "100",
            "--json", "number,state,headRefOid",
        ]
        let result = try await run("gh", arguments, cwd: worktree, timeout: .seconds(20), repositoryContext: context)
        guard result.ok else { throw shellError(arguments: arguments, result: result) }
        return try decodeBranchPullRequests(from: Data(result.stdout.utf8))
    }

    static func decodeBranchPullRequests(from data: Data) throws -> [BranchPullRequest] {
        try JSONDecoder().decode([BranchPullRequestPayload].self, from: data).compactMap { payload in
            guard let number = payload.number, number > 0 else { return nil }
            return BranchPullRequest(
                number: number,
                isOpen: payload.state?.uppercased() == "OPEN",
                headCommit: payload.headCommit
            )
        }
    }
}

private struct BranchPullRequestPayload: Decodable {
    enum CodingKeys: String, CodingKey {
        case number, state
        case headCommit = "headRefOid"
    }

    let number: Int?
    let state: String?
    let headCommit: String?
}
