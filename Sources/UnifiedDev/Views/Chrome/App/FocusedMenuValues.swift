import SwiftUI
import Core

extension FocusedValues {
    @Entry var composerTranscript: TranscriptModel?

    @Entry var notesFormatting: NotesFormattingContext?

    @Entry var focusedWorkspaceRow: FocusedWorkspaceRow?

    @Entry var saveAction: SaveAction?

    @Entry var isTypingProse: Bool?

    @Entry var homeScopeCounts: HomeScopeCounts?
}

struct FocusedWorkspaceRow: Equatable {
    var workspace: Workspace
    var isArchived: Bool

    var row: WorkspaceMenuSubject.FocusedRow {
        WorkspaceMenuSubject.FocusedRow(id: workspace.id, isArchived: isArchived)
    }
}

struct SaveAction: Equatable {
    var subject: String
    var isEnabled: Bool
    var perform: @MainActor () -> Void

    static func == (lhs: SaveAction, rhs: SaveAction) -> Bool {
        lhs.subject == rhs.subject && lhs.isEnabled == rhs.isEnabled
    }
}
