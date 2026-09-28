import Foundation

public enum HunkDiscard {
    public enum Availability: Equatable, Sendable {
        case hidden
        case enabled
        case disabled(String)
    }

    public static let gitlinkMode = "160000"

    public static let whitespaceIsHidden =
        "Turn off Ignore whitespace to discard a single hunk. The hunks shown are not the ones on disk"

    public static let draftIsOpen =
        "Save or throw away your unsaved edits to this file before discarding a single hunk"

    public static func offers(_ file: ChangedFile, in diff: FileDiff? = nil) -> Bool {
        guard !file.isBinary else { return false }
        if let diff, diff.oldMode == gitlinkMode || diff.newMode == gitlinkMode { return false }
        switch file.change {
        case .modified, .renamed: return true
        case .added, .deleted, .untracked, .copied, .typechange: return false
        }
    }

    public static func availability(
        file: ChangedFile, in diff: FileDiff? = nil, ignoringWhitespace: Bool,
        blocker: String?, hasUnsavedEdits: Bool
    ) -> Availability {
        guard offers(file, in: diff) else { return .hidden }
        if let blocker { return .disabled(blocker) }
        if hasUnsavedEdits { return .disabled(draftIsOpen) }
        if ignoringWhitespace { return .disabled(whitespaceIsHidden) }
        return .enabled
    }

    public static func refusal(
        file: ChangedFile, in diff: FileDiff? = nil, ignoringWhitespace: Bool,
        blocker: String?, hasUnsavedEdits: Bool
    ) -> String? {
        switch availability(
            file: file, in: diff, ignoringWhitespace: ignoringWhitespace,
            blocker: blocker, hasUnsavedEdits: hasUnsavedEdits
        ) {
        case .enabled: nil
        case .hidden: HunkDiscardRefusal.notOffered.errorDescription
        case let .disabled(reason): reason
        }
    }

    public static func question(path: String) -> String {
        "Discard this hunk in \(path)?"
    }

    public static func losses(of hunk: DiffHunk) -> String {
        let added = hunk.lines.filter { $0.kind == .addition }.count
        let removed = hunk.lines.filter { $0.kind == .deletion }.count
        let clauses = [
            removed > 0 ? "puts back \(Counted.of(removed, "removed line"))" : nil,
            added > 0 ? "takes out \(Counted.of(added, "added line"))" : nil,
        ].compactMap { $0 }
        let change = clauses.isEmpty ? "This undoes the change" : "This " + clauses.joined(separator: " and ")
        return change + ". The rest of the file is left as it is.\n\n" + NoUndo.sentence
    }
}
