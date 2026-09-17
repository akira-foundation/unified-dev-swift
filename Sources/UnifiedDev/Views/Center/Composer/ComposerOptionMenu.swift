import SwiftUI

struct ComposerOptionMenu: View {
    var options: [ComposerOption]
    var sections: [ComposerModelSection]?
    var selection: String
    var heading: String?
    var systemImage: String
    var tint: Color = Palette.textSecondary
    var isCompact: Bool = false
    var help: String
    var onSelect: @MainActor (String) -> Void

    var body: some View {
        Menu {
            rows
        } label: {
            ComposerControlLabel(
                systemImage: systemImage,
                text: isCompact ? nil : label,
                tint: tint,
                showsMenuIndicator: true
            )
        }
        .menuStyle(.button)
        .buttonStyle(.glass)
        .menuIndicator(.hidden)
        .fixedSize(horizontal: false, vertical: true)
        .help(help)
        .accessibilityLabel(help)
        .accessibilityValue(label)
    }

    @ViewBuilder
    private var rows: some View {
        let picker = Picker(heading ?? help, selection: binding) {
            if let sections {
                ForEach(sections) { section in
                    Section(section.title) {
                        ForEach(section.options) { option in
                            Text(option.label).tag(option.id)
                        }
                    }
                }
            } else {
                ForEach(options) { option in
                    Text(option.label).tag(option.id)
                }
            }
        }
        .pickerStyle(.inline)

        if heading == nil {
            picker.labelsHidden()
        } else {
            picker
        }
    }

    private var binding: Binding<String> {
        Binding(get: { selection }, set: { id in MainActor.assumeIsolated { onSelect(id) } })
    }

    private var label: String {
        ComposerOption.label(for: selection, in: sections?.flatMap(\.options) ?? options)
    }
}
