import Foundation

public enum HandoffWorktree {
    public static func read(path: String, base: String) async -> ConversationHandoff.Worktree? {
        do {
            guard let branch = try await Git.currentBranch(of: path) else { return nil }
            let files = try await Git.changedFiles(worktree: path, base: base)
            return ConversationHandoff.Worktree(branch: branch, files: files.map(line))
        } catch {
            return nil
        }
    }

    private static func line(_ file: ChangedFile) -> String {
        file.isBinary ? file.path : "\(file.path) (+\(file.additions) -\(file.deletions))"
    }
}
