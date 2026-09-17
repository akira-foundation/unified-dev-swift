import SwiftUI
import Core

struct NotesGallery: View {
    var app: AppModel

    @State private var text = Self.sample
    @FocusState private var isEditing: Bool

    var body: some View {
        NotesPage(
            text: $text,
            isEditing: $isEditing,
            workspaceID: WorkspaceID("gallery"),
            workspaceName: "Arafura Sea",
            hasLoaded: true,
            couldNotLoad: false,
            couldNotSave: false,
            hasChanges: false,
            onRetryLoad: {},
            onRetrySave: {}
        )
    }

    private static let sample = """
    # Before the morning run

    The composer takes the keyboard on arrival, which is why the sidebar flashes.

    - check the merge band at the narrow width
    - `WorkspaceNote.autosaveDelay` is two seconds

    > Ask the agent to start from the diff, not from the branch name.
    """
}

extension Gallery {
    static let notes = Gallery(
        name: "notes",
        title: "Notes",
        size: CGSize(width: 900, height: 700),
        needsFocus: false,
        view: { app in AnyView(NotesGallery(app: app)) }
    )
}
