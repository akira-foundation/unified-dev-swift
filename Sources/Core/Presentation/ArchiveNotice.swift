import Foundation

public enum ArchiveNotice {
    public static func after(
        archiving workspaceName: String, preservedFolderPath: String?, stopping commands: [Subagent]
    ) -> Notice? {
        let fact = "\(workspaceName) was archived."
        let stopped = BackgroundWork.stopped(commands)
        guard let preservedFolderPath else {
            return stopped.map { Notice(message: "\(fact) \($0)") }
        }
        let kept = "Its folder at `\(preservedFolderPath)` and its branch were kept because Git no longer "
            + "recognises the folder as a worktree. The archive script was skipped."
        return Notice(
            message: [fact, kept, stopped].compactMap { $0 }.joined(separator: " "),
            tone: .warning,
            dismissal: .untilDismissed
        )
    }
}
