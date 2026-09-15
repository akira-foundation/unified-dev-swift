import SwiftUI
import Core

/// Familiar formatting actions, with Markdown source available for direct editing.
///
/// `.accessoryBar`, which is the style macOS draws for a row of controls INSIDE a view rather than
/// in a window's toolbar: no plate at rest, a rounded plate under the pointer, and a filled one
/// while a toggle is on. The bar was `.borderless` before, so nothing under the pointer said a
/// glyph could be pressed, and the Source toggle was a bordered capsule that read as the one
/// important control on the page.
struct NotesFormattingBar: View {
    var commands: NotesFormattingCommands
    var isEditing: Bool
    @Binding var showsSource: Bool
    @State private var showsLink = false
    @State private var linkURL = ""
    @FocusState private var isURLFocused: Bool

    var body: some View {
        HStack(spacing: Metrics.spacing) {
            // One capsule per group of related edits, which is what the toolbar of Notes, Mail and
            // Finder draws under Tahoe: a glyph inside a group carries no border of its own,
            // because the group is the visible container. `ControlGroup` is the in-view spelling
            // of `ToolbarItemGroup`, so the shape, the divider between members and the pressed
            // states are the system's rather than ours.
            ControlGroup {
                Menu {
                    ForEach(1...3, id: \.self) { level in
                        Button("Heading \(level)") { commands.apply(.heading(level)) }
                    }
                } label: {
                    Label("Heading", systemImage: "textformat.size")
                }
                .help("Heading")

                button("Bold", symbol: "bold", action: .bold, shortcut: "b")
                button("Italic", symbol: "italic", action: .italic, shortcut: "i")
                button("Inline code", symbol: "chevron.left.forwardslash.chevron.right", action: .code)
            }
            .fixedSize()

            ControlGroup {
                Menu {
                    Button("Bulleted list", systemImage: "list.bullet") { commands.apply(.bulletList) }
                    Button("Numbered list", systemImage: "list.number") { commands.apply(.numberedList) }
                } label: {
                    Label("List", systemImage: "list.bullet")
                }
                .help("List")

                Button {
                    linkURL = ""
                    showsLink = true
                } label: {
                    Label("Link", systemImage: "link")
                }
                .help("Insert link")
                .keyboardShortcut(isEditing ? KeyboardShortcut("k", modifiers: .command) : nil)
                .popover(isPresented: $showsLink) { linkPopover }

                Menu {
                    Button("Code block", systemImage: "curlybraces") { commands.apply(.codeBlock) }
                    Button("Quote", systemImage: "text.quote") { commands.apply(.quote) }
                } label: {
                    Label("More formatting", systemImage: "ellipsis")
                }
                .help("More formatting")
            }
            .fixedSize()

            // The one control here that is a mode rather than an edit, so it stands alone at the
            // trailing end with the whole bar between it and the things that change the text.
            Spacer(minLength: Metrics.spacing)

            Toggle(isOn: $showsSource) {
                Label("Source", systemImage: "doc.plaintext")
            }
            .toggleStyle(.button)
            .buttonStyle(.bordered)
            .help("Show the Markdown syntax")
        }
        .controlSize(.large)
        .labelStyle(.iconOnly)
        .menuIndicator(.hidden)
        .frame(height: Metrics.barHeight)
    }

    private func button(_ title: String, symbol: String, action: NoteFormatting.Action, shortcut: KeyEquivalent? = nil) -> some View {
        Button { commands.apply(action) } label: {
            Label(title, systemImage: symbol)
        }
        .help(title)
        .keyboardShortcut(isEditing ? shortcut.map { KeyboardShortcut($0, modifiers: .command) } : nil)
    }

    private var linkPopover: some View {
        VStack(alignment: .leading, spacing: Metrics.inset) {
            Text("Insert link").font(Typo.bodyEmphasis)
            TextField("https://example.com", text: $linkURL)
                .textFieldStyle(.roundedBorder)
                .focused($isURLFocused)
                .onSubmit(insertLink)
                .onExitCommand { showsLink = false }
            HStack {
                Spacer()
                Button("Insert link", action: insertLink)
                    .buttonStyle(.borderedProminent)
                    .disabled(linkURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(Metrics.pane)
        .frame(width: 300)
        .task { isURLFocused = true }
    }

    private func insertLink() {
        let url = linkURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !url.isEmpty else { return }
        showsLink = false
        commands.apply(.link(url))
    }
}
