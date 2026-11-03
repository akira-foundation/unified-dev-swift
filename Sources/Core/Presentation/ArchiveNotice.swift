import Foundation

public enum ArchiveNotice {
    public static func after(
        archiving workspaceName: String,
        preservedFolderPath: String?,
        keptBranch: ArchiveKeptBranch? = nil,
        stopping commands: [Subagent]
    ) -> Notice? {
        let fact = "\(workspaceName) was archived."
        let stopped = BackgroundWork.stopped(commands)
        let preserved = preservedFolderPath.map {
            "Its folder at `\($0)` and its branch were kept because Git no longer "
                + "recognises the folder as a worktree. The archive script was skipped."
        }
        guard let kept = preserved ?? keptBranch?.sentence else {
            return stopped.map { Notice(message: "\(fact) \($0)") }
        }
        return Notice(
            message: [fact, kept, stopped].compactMap { $0 }.joined(separator: " "),
            tone: .warning,
            dismissal: .untilDismissed
        )
    }
}
