import AppKit
import SwiftUI
import Core

struct AppearanceSettingsView: View {
    @AppStorage("appearance") private var appearance = "system"
    @AppStorage(ChatTextSize.defaultsKey) private var chatTextSize = ChatTextSize.defaultChoice
    @AppStorage(ChatFont.defaultsKey) private var chatFontID = ChatFont.standardID
    @AppStorage(ChatLineHeight.defaultsKey) private var chatLineHeight = ChatLineHeight.defaultChoice
    var body: some View {
        Form {
            Section("Theme") {
                Picker("Appearance", selection: $appearance) {
                    Text("System").tag("system")
                    Text("Light").tag("light")
                    Text("Dark").tag("dark")
                }
                .pickerStyle(.segmented)
            }

            Section {
                Picker("Font", selection: fontSelection) {
                    Section {
                        ForEach(ChatFontCatalogue.curated) { face in
                            Text(face.title).tag(face.id)
                        }
                    }

                    Section("Installed on this Mac") {
                        ForEach(ChatFont.familyChoices(keeping: chatFontID), id: \.self) { family in
                            // Each name set in its own face, which is what a font menu is for:
                            // three hundred names in one face is a list to read, and the same
                            // three hundred in their own faces is a list to look at.
                            Text(family)
                                .font(.custom(family, fixedSize: NSFont.systemFontSize))
                                .tag(family)
                        }
                    }
                }

                Text(ChatFont.summary(for: chatFontID))
                    .settingsFootnote()

                Picker("Text size", selection: $chatTextSize) {
                    ForEach(ChatTextSize.allCases) { size in
                        Text(size.title).tag(size)
                    }
                }
                .pickerStyle(.segmented)

                Picker("Line height", selection: $chatLineHeight) {
                    ForEach(ChatLineHeight.allCases) { step in
                        Text(step.title).tag(step)
                    }
                }
                .pickerStyle(.segmented)

                ChatTextPreview()
                    .environment(\.fontScale, chatTextSize.scale)
                    .environment(\.chatFont, ChatFont(rawValue: chatFontID))
                    .environment(\.chatLineHeight, chatLineHeight)
            } header: {
                Text("Conversation")
            } footer: {
                Text("Applies to what an agent says and to what you type. The rest of the window follows System Settings.")
                    .settingsFootnote()
            }

        }
        .settingsForm()
        // The picker only records the choice; this is what makes the running app take it.
        .onAppear { AppearancePreference.apply(appearance) }
        .onChange(of: appearance) { _, value in AppearancePreference.apply(value) }
    }

    /// The stored font, read as the id it means today.
    ///
    /// A setting made before the font list existed is still spelled `book` or `legible` in
    /// defaults, and the rows are tagged with the family names those two became, so binding the
    /// raw string straight to the picker would show no row selected for anybody who had chosen
    /// one of them. Canonicalising on the way in is what makes Book still read as Book, and
    /// writing through the plain binding is what retires the old spelling the first time the
    /// setting is touched. See `ChatFontCatalogue.canonicalID`.
    private var fontSelection: Binding<String> {
        Binding(
            get: { ChatFontCatalogue.canonicalID(chatFontID) },
            set: { chatFontID = $0 }
        )
    }

}

/// A few rungs of the conversation at once, because one line of body text cannot show what a scale
/// does: what the setting changes is the distance between a heading, a sentence and a filename.
///
/// Drawn by the transcript's own renderer rather than by a hand-built stack of `Text`, because the
/// two questions a face has to answer here are how a paragraph reads and how a span of inline code
/// sits inside it, and only the real renderer pairs the two the way the transcript will. Written
/// as markdown for the same reason: this is the shape an agent actually replies in.
private struct ChatTextPreview: View {
    private static let sample = """
    **Ran the test suite**

    All 443 tests pass. **Cause:** a stale snapshot in `DiffParserTests.swift`, not the parser. \
    **Fix:** regenerated it with `swift test --update-snapshots` and left `parse(hunk:)` alone.
    """

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.spacing) {
            // Led the way the transcript leads it, off the same environment the pickers above
            // write. This is the only control in the pane whose effect is invisible without the
            // preview: a step is a couple of points between lines, which nobody can picture from
            // the word "Looser" and everybody can see in a paragraph.
            // `Text` with markdown, not `MarkdownView`. The transcript's renderer is a TextKit
            // view that measures itself against a width nobody gives it inside a form row: it
            // drew a column an inch wide and reported that height, so the chips below were laid
            // over the paragraph. What this pane has to show is the face, the size and the
            // leading, and `Text` shows those and lays out where it is put.
            Text(.init(Self.sample))
                .proseLeading()
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: Metrics.spacing) {
                Chip(text: "Sources/Core/Store.swift", systemImage: "doc", monospaced: true)
                DiffStatLabel(additions: 118, deletions: 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Metrics.inset)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: Metrics.corner))
        .overlay {
            RoundedRectangle(cornerRadius: Metrics.corner)
                .strokeBorder(Palette.border, lineWidth: Metrics.outline)
        }
        .accessibilityLabel("Preview of the conversation in this font, text size and line height")
    }
}
