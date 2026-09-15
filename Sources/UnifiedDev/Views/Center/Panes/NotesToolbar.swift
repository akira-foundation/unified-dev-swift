import SwiftUI
import Core

/// What the notes pane hands the window's toolbar while it is on screen.
///
/// A value rather than a view, and this is the whole of why the formatting controls left the pane.
/// They were a strip inside the page, which is a bar of ours a few points away from the bar the
/// window already has: two rows of glyphs stacked on one another, only one of them drawn by the
/// system. Apple's own editors put these in the window's toolbar, and the guidance this repository
/// already quotes says a control that changes what the view shows belongs in the toolbar rather
/// than in a strip under it. A version on glass inside the pane was tried and photographed
/// alongside this one; this is the one that reads better and it is the one that is drawn.
///
/// It reaches the toolbar through `FocusedValues`, which is the same channel the menu bar reads a
/// selected row off. Published with `focusedSceneValue`, not `focusedValue`: the pane does not take
/// the keyboard when it opens, and controls that vanish unless the text view holds first responder
/// would be controls nobody could find.
struct NotesFormattingContext: Equatable {
    var commands: NotesFormattingCommands
    var showsSource: Binding<Bool>
    /// Whether the note has been read back, which is what greys the whole group out.
    var isEnabled: Bool
    /// Whether the text view holds the keyboard, which is what arms Cmd+B and its siblings. A
    /// shortcut bound while somebody is typing in the composer would edit a note nobody is looking
    /// at.
    var isEditing: Bool

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.commands === rhs.commands
            && lhs.showsSource.wrappedValue == rhs.showsSource.wrappedValue
            && lhs.isEnabled == rhs.isEnabled
            && lhs.isEditing == rhs.isEditing
    }
}

/// The notes' formatting controls, as real toolbar items.
///
/// Two groups and a toggle, which is the shape the window's other screens already use: the
/// inspector's picker and its group of three, Home's scope and its project menu. A group is one
/// capsule with the system's own dividers between its items, so nothing here draws a plate, a rim
/// or a separator of its own.
struct NotesToolbar: ToolbarContent {
    var context: NotesFormattingContext

    var body: some ToolbarContent {
        ToolbarItemGroup(placement: .principal) {
            Menu {
                ForEach(1...3, id: \.self) { level in
                    Button("Heading \(level)") { context.commands.apply(.heading(level)) }
                }
            } label: {
                Label("Heading", systemImage: "textformat.size")
            }
            .help("Heading")

            button("Bold", symbol: "bold", action: .bold, shortcut: "b")
            button("Italic", symbol: "italic", action: .italic, shortcut: "i")
            button("Inline code", symbol: "chevron.left.forwardslash.chevron.right", action: .code)
        }

        ToolbarSpacer(.fixed, placement: .principal)

        ToolbarItemGroup(placement: .principal) {
            Menu {
                Button("Bulleted list", systemImage: "list.bullet") {
                    context.commands.apply(.bulletList)
                }
                Button("Numbered list", systemImage: "list.number") {
                    context.commands.apply(.numberedList)
                }
            } label: {
                Label("List", systemImage: "list.bullet")
            }
            .help("List")

            NotesLinkButton(commands: context.commands, isEditing: context.isEditing)

            Menu {
                Button("Code block", systemImage: "curlybraces") {
                    context.commands.apply(.codeBlock)
                }
                Button("Quote", systemImage: "text.quote") { context.commands.apply(.quote) }
            } label: {
                Label("More formatting", systemImage: "ellipsis")
            }
            .help("More formatting")
        }

        ToolbarSpacer(.fixed, placement: .principal)

        // A mode rather than an edit, so it stands on its own rather than inside either group.
        ToolbarItem(placement: .principal) {
            Toggle(isOn: context.showsSource) {
                Label("Source", systemImage: "doc.plaintext")
            }
            .help("Show the Markdown syntax")
            .disabled(!context.isEnabled)
        }
    }

    private func button(
        _ title: String, symbol: String, action: NoteFormatting.Action,
        shortcut: KeyEquivalent? = nil
    ) -> some View {
        Button { context.commands.apply(action) } label: {
            Label(title, systemImage: symbol)
        }
        .help(title)
        .disabled(!context.isEnabled)
        .keyboardShortcut(
            context.isEditing ? shortcut.map { KeyboardShortcut($0, modifiers: .command) } : nil
        )
    }
}

/// The link item, which is the one control here that opens something and so needs state of its own.
private struct NotesLinkButton: View {
    var commands: NotesFormattingCommands
    var isEditing: Bool

    @State private var isPresented = false
    @State private var url = ""
    @FocusState private var isURLFocused: Bool

    var body: some View {
        Button {
            url = ""
            isPresented = true
        } label: {
            Label("Insert link", systemImage: "link")
        }
        .help("Insert link")
        .keyboardShortcut(isEditing ? KeyboardShortcut("k", modifiers: .command) : nil)
        .popover(isPresented: $isPresented) { form }
    }

    private var form: some View {
        VStack(alignment: .leading, spacing: Metrics.inset) {
            Text("Insert link").font(Typo.bodyEmphasis)
            TextField("https://example.com", text: $url)
                .textFieldStyle(.roundedBorder)
                .focused($isURLFocused)
                .onSubmit(insert)
                .onExitCommand { isPresented = false }
            HStack {
                Spacer()
                Button("Insert link", action: insert)
                    .buttonStyle(.borderedProminent)
                    .disabled(url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(Metrics.pane)
        .frame(width: 300)
        .task { isURLFocused = true }
    }

    private func insert() {
        let address = url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !address.isEmpty else { return }
        isPresented = false
        commands.apply(.link(address))
    }
}
