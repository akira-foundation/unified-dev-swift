import Foundation

extension WorkspaceManager {
    static func startPoint(of base: String, in repo: String, acceptsStaleBase: Bool = true) async throws -> String {
        guard Git.isValidBranchName(base) else { return base }
        let remote = Git.primaryRemote(of: (try? await Git.remoteNames(of: repo)) ?? [])

        if let remote {
            let fetched = await BaseBranchFetches.shared.refresh(
                base, in: repo, remote: remote, acceptingWithin: BaseBranchFetches.recent
            )
            if let revision = await Git.revision(of: "refs/remotes/\(remote)/\(base)", in: repo) {
                try BaseNotFetched.check(
                    fetched: fetched, acceptsStaleBase: acceptsStaleBase, branch: base, remote: remote
                )
                return revision
            }
        }
        if let revision = await Git.revision(of: "refs/heads/\(base)", in: repo) { return revision }
        if await Git.revision(of: base, in: repo) != nil { return base }

        throw ShellError(
            command: "git rev-parse \(base)",
            status: 1,
            stderr: "Unified Dev could not find \(base) in this repository"
                + (remote.map { " or on \($0)." } ?? ".")
        )
    }
}
