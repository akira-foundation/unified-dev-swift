import Foundation

public enum RevertOutcome: Equatable, Sendable {
    case reverted
    case refused(String)
    case failed(String)

    public var discardsDraft: Bool { self == .reverted }

    public var refreshesChanges: Bool {
        guard case .refused = self else { return true }
        return false
    }
}

public enum WorktreeFileRevert {
    public static func revert(_ file: ChangedFile, in workspace: Workspace, refusal: String?) async -> RevertOutcome {
        if let refusal { return .refused(refusal) }
        if file.change == .untracked {
            let absolute = (workspace.path as NSString).appendingPathComponent(file.path)
            do {
                try FileManager.default.trashItem(at: URL(fileURLWithPath: absolute), resultingItemURL: nil)
                return .reverted
            } catch {
                return .failed("It could not be moved to the Trash: \(error.localizedDescription)")
            }
        }
        do {
            try await Git.revertTrackedFile(file, worktree: workspace.path, base: workspace.baseBranch)
            return .reverted
        } catch let error as ShellError {
            return .failed(error.stderr.trimmingCharacters(in: .whitespacesAndNewlines))
        } catch {
            return .failed(error.localizedDescription)
        }
    }
}
