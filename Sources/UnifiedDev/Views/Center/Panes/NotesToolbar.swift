import SwiftUI
import Core

struct NotesFormattingContext: Equatable {
    var commands: NotesFormattingCommands
    var showsSource: Binding<Bool>
    var isEnabled: Bool
    var isEditing: Bool

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.commands === rhs.commands
            && lhs.showsSource.wrappedValue == rhs.showsSource.wrappedValue
            && lhs.isEnabled == rhs.isEnabled
            && lhs.isEditing == rhs.isEditing
    }
}

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
