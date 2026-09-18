import Foundation

public enum ArchiveNotice {
    public static func after(
        archiving workspaceName: String, preservedFolderPath: String?, stopping commands: [Subagent]
    ) -> Notice? {
        guard let preservedFolderPath else {
            return BackgroundWork.archived(workspaceName, stopping: commands).map { Notice(message: $0) }
        }
        return Notice(
            message: "\(workspaceName) was archived. Its folder at `\(preservedFolderPath)` and its branch "
                + "were kept because Git no longer recognises the folder as a worktree. "
                + "The archive script was skipped.",
            tone: .warning,
            dismissal: .untilDismissed
        )
    }
}
