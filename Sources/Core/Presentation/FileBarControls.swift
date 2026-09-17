import Foundation

public struct FileBarControl: Equatable, Sendable {
    public let title: String
    public let hint: String

    public init(title: String, hint: String) {
        self.title = title
        self.hint = hint
    }
}

public enum FileBarControls {
    public static let revertWhileAgentWorks =
        "Wait for the agent to finish its turn before reverting this file"

    public static func revertBlocker(isAgentRunning: Bool, isAwaitingPermission: Bool) -> String? {
        isAgentRunning || isAwaitingPermission ? revertWhileAgentWorks : nil
    }

    public static func revert(filename: String, blocker: String? = nil) -> FileBarControl {
        FileBarControl(
            title: "Revert file",
            hint: blocker ?? "Throw away the changes to \(filename) and put it back the way git has it"
        )
    }

    public static let unified = "Unified"
    public static let sideBySide = "Side by side"

    public static let layout = FileBarControl(
        title: "Layout",
        hint: "Show the diff as one column, or the old and the new side by side"
    )

    public static func whitespace(ignoring: Bool) -> FileBarControl {
        FileBarControl(
            title: "Ignore whitespace",
            hint: ignoring
                ? "Show the changes that are only whitespace again"
                : "Hide the changes that are only whitespace, such as reindenting"
        )
    }

    public static func copy(mode: FileViewMode, didCopy: Bool = false) -> FileBarControl {
        let title = mode == .edit ? "Copy file" : "Copy diff"
        let subject = mode == .edit ? "file" : "diff"
        return FileBarControl(
            title: title,
            hint: didCopy
                ? "The \(subject) is on the clipboard"
                : "Copy this \(subject) to the clipboard"
        )
    }

    public static let more = FileBarControl(
        title: "More",
        hint: "More things to do with this file"
    )

    public static func mode(filename: String, isEditable: Bool) -> FileBarControl {
        FileBarControl(
            title: "File view",
            hint: isEditable
                ? "Switch between what changed and the whole of \(filename), which you can edit here"
                : "\(filename) cannot be edited here"
        )
    }
}
