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

    public static func afterFailing(_ sentence: String, stopping commands: [Subagent]) -> String {
        [sentence, BackgroundWork.stopped(commands)].compactMap { $0 }.joined(separator: " ")
    }

    public static func scriptFailure(
        workspaceName: String, status: Int32, output: String, stopping commands: [Subagent]
    ) -> String {
        let kept = "\u{201C}\(workspaceName)\u{201D} is still here: its worktree and its branch are "
            + "untouched. Any agent it was running has been stopped."
        return afterFailing(kept, stopping: commands)
            + "\n\nThe script exited with status \(status).\n\n"
            + String(output.trimmingCharacters(in: .whitespacesAndNewlines).suffix(1_000))
    }

    public static func everyCommandStopped(earlier: [Subagent], now: [Subagent]) -> [Subagent] {
        let known = Set(earlier.map(\.id))
        return earlier + now.filter { !known.contains($0.id) }
    }
}
