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

            FileIconsSettingsSection()

            Section {
                Picker("Font", selection: fontSelection) {
                    Section {
                        ForEach(ChatFontCatalogue.curated) { face in
                            Text(face.title).tag(face.id)
                        }
                    }

                    Section("Installed on this Mac") {
                        ForEach(ChatFont.familyChoices(keeping: chatFontID), id: \.self) { family in
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
        .onAppear { AppearancePreference.apply(appearance) }
        .onChange(of: appearance) { _, value in AppearancePreference.apply(value) }
    }

    private var fontSelection: Binding<String> {
        Binding(
            get: { ChatFontCatalogue.canonicalID(chatFontID) },
            set: { chatFontID = $0 }
        )
    }
}

private struct ChatTextPreview: View {
    private static let sample = """
    **Ran the test suite**

    All 443 tests pass. **Cause:** a stale snapshot in `DiffParserTests.swift`, not the parser. \
    **Fix:** regenerated it with `swift test --update-snapshots` and left `parse(hunk:)` alone.
    """

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.spacing) {
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
