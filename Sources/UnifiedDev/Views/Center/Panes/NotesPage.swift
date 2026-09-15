import SwiftUI
import Core

/// The notes' writing surface. Persistence stays with NotesPaneView.
///
/// **A page rather than a screen with a heading on it.** It used to open with "Notes" set in the
/// title face and the workspace's name under it, which is the tab's own label and the window's own
/// title said a third time, and it cost the first eighty points of a pane whose whole job is
/// somewhere to write. The page opens on the text now, which is what TextEdit, Notes and every
/// other editor on this Mac do.
///
/// The column is the reading measure and it is CENTRED, which the old one was not: the text was
/// capped and then pinned to the leading edge, so on a wide window the words sat in the left third
/// with a third of the pane empty beside them. The bar above it is the same width as the column, so
/// the controls line up with the first character of every line rather than floating over the page.
struct NotesPage: View {
    @Binding var text: String
    var isEditing: FocusState<Bool>.Binding
    var workspaceID: WorkspaceID
    var workspaceName: String
    var hasLoaded: Bool
    var couldNotLoad: Bool
    var couldNotSave: Bool
    var hasChanges: Bool
    var onRetryLoad: () -> Void
    var onRetrySave: () -> Void

    @State private var commands = NotesFormattingCommands()
    @State private var showsSource = false

    static let textPadding: CGFloat = 5

    /// The width of a line of prose, and of the bar over it.
    ///
    /// Narrower than the transcript's, deliberately: a transcript is read and this is written, and
    /// a line somebody is typing into wants to be shorter than one they are only scanning.
    private static let measure: CGFloat = 680

    var body: some View {
        VStack(spacing: 0) {
            editor
                .frame(maxWidth: Self.measure)
                .padding(.horizontal, Metrics.pane)
                // Air over the first line. A caret against the top edge of a pane reads as text
                // that has been cut off rather than as a page waiting to be written on.
                .padding(.top, Metrics.pane)

            // Only when there is something to say. A line reading "Saved with this workspace"
            // under every note said, permanently, that a text field saves: the one moment worth a
            // word is the one where it did not.
            footer
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // The formatting controls, drawn by the window's toolbar rather than by a strip of ours
        // under it. See `NotesFormattingContext`.
        .focusedSceneValue(\.notesFormatting, NotesFormattingContext(
            commands: commands,
            showsSource: $showsSource,
            isEnabled: hasLoaded,
            isEditing: isEditing.wrappedValue
        ))
    }

    private var editor: some View {
        NotesMarkdownEditor(text: $text, isEditing: isEditing, workspaceID: workspaceID,
                            isEditable: hasLoaded, showsSource: showsSource, commands: commands)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(alignment: .topLeading) { unreadable }
    }

    @ViewBuilder
    private var unreadable: some View {
        if couldNotLoad {
            VStack(alignment: .leading, spacing: Metrics.inset) {
                Text(WorkspaceNote.unreadable)
                    .font(Typo.body)
                    .foregroundStyle(Palette.textSecondary)
                Button("Try again", action: onRetryLoad)
                    .buttonStyle(.bordered)
            }
            .padding(.horizontal, Self.textPadding)
            .padding(.top, Metrics.spacingWide)
            .padding(.bottom, Metrics.inset)
        }
    }

    @ViewBuilder
    private var footer: some View {
        if couldNotSave {
            status {
                Text(WorkspaceNote.unwritable)
                    .foregroundStyle(Palette.warning)
                Button("Try saving again", action: onRetrySave)
                    .buttonStyle(.link)
            }
        } else if couldNotLoad {
            status { Text("Notes could not be loaded") }
        } else if !hasLoaded {
            status { Text("Loading notes…") }
        } else if hasChanges {
            status { Text("Saving…") }
        }
    }

    private func status(@ViewBuilder _ content: () -> some View) -> some View {
        HStack(spacing: Metrics.spacingSmall) { content() }
            .font(Typo.caption)
            .foregroundStyle(Palette.textTertiary)
            .frame(maxWidth: Self.measure, alignment: .leading)
            .padding(.horizontal, Metrics.pane + Self.textPadding)
            .padding(.vertical, Metrics.inset)
    }
}
