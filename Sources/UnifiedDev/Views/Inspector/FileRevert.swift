import Foundation
import Core

enum FileRevert {
    static func losses(for file: ChangedFile, in workspace: Workspace, hasDraft: Bool) -> String {
        var text: String

        switch file.change {
        case .untracked:
            text = "\(file.path) is not tracked by git, so there is no version to go back to. "
                + "Reverting moves it to the Trash."
        case .added:
            text = "\(file.path) did not exist on \(workspace.baseBranch). Reverting deletes it."
        default:
            text = "Reverting restores \(file.path) to the version on \(workspace.baseBranch)."
        }

        let changed = file.additions + file.deletions
        if changed > 0 {
            text += "\n\nThis would lose:\n\u{2022} \(file.additions) added and "
                + "\(file.deletions) removed lines in \(file.filename)"
        }
        if hasDraft {
            text += "\n\u{2022} the unsaved edits you have open in Edit mode"
        }
        text += "\n\nThere is no undo for this."
        return text
    }
}
