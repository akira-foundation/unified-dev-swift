import SwiftUI
import Core

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

    private static let measure: CGFloat = 680

    var body: some View {
        VStack(spacing: 0) {
            editor
                .frame(maxWidth: Self.measure)
                .padding(.horizontal, Metrics.pane)
                .padding(.top, Metrics.pane)

            footer
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                    .linkButton()
            }
        }
        if !couldNotSave, let progress {
            status { Text(progress) }
        }
    }

    private var progress: String? {
        if couldNotLoad { return "Notes could not be loaded" }
        if !hasLoaded { return "Loading notes…" }
        return hasChanges ? "Saving…" : nil
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
