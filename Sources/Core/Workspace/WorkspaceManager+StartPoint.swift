import Foundation

extension WorkspaceManager {
    static func startPoint(of base: String, in repo: String) async -> String {
        guard Git.isValidBranchName(base),
              let resolved = try? await Git.baseRevision(
                branch: base, in: repo, acceptingFetchWithin: BaseBranchFetches.recent
              )
        else { return base }
        return resolved.revision
    }
}
