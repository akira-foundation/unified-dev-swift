import SwiftUI
import Core

/// The control that opens another tab in a workspace.
///
/// One type, drawn twice: at the end of the tab strip, and in the window toolbar. The strip's copy
/// is where the tabs are, the toolbar's is where every other window-level action lives, and both
/// have to offer the same four kinds in the same words or the two lists drift.
///
/// A `Menu` with a primary action, which is what AppKit draws as a split capsule: the glyph, a
/// divider, the chevron, one plate around both. Pressing the glyph opens a conversation, the same
/// thing Cmd+T does; the chevron opens the rest.
struct NewTabMenu: View {
    @Bindable var model: WorkspaceModel

    private var store: WorkspaceTabsStore { .shared }

    var body: some View {
        Menu {
            Button(PaneKind.chat.title, systemImage: PaneKind.chat.symbol, action: newChat)
                .keyboardShortcut("t", modifiers: .command)
            Button(PaneKind.terminal.title, systemImage: PaneKind.terminal.symbol, action: newTerminal)
                .keyboardShortcut("t", modifiers: [.command, .shift])
            Button(PaneKind.browser.title, systemImage: PaneKind.browser.symbol, action: newBrowser)
                .keyboardShortcut("b", modifiers: [.command, .shift])
            Divider()
            Button("Changes", systemImage: "doc.text") { FileReview.open(in: model) }
                .keyboardShortcut("d", modifiers: [.command, .shift])
            Button(CenterTab.notesTitle, systemImage: "note.text") { WorkspaceNotes.open(in: model) }
        } label: {
            Label("New tab", systemImage: "plus")
                .labelStyle(.iconOnly)
        } primaryAction: {
            newChat()
        }
        .menuStyle(.button)
        .buttonStyle(.glass)
        .help("New tab in this workspace")
        .accessibilityLabel("New tab in this workspace")
    }

    private func newChat() {
        NewPane.open(.chat, in: model) { store.select($0, in: model) }
    }

    private func newTerminal() {
        NewPane.open(.terminal, in: model) { store.select($0, in: model) }
    }

    /// The `+` opens a browser on the workspace's own dev server, where a split opens one on
    /// nothing: this control is the one that means "look at what this workspace is running".
    private func newBrowser() {
        Task {
            let address = await model.browserAddress()
            NewPane.open(.browser, in: model, url: address) { store.select($0, in: model) }
        }
    }
}
