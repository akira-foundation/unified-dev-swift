import SwiftUI

struct ComposerOptionPicker: View {
    var options: [ComposerOption]
    var footnote: String?
    var selection: String
    var heading: String
    var systemImage: String
    var tint: Color = Palette.textSecondary
    var isCompact: Bool = false
    var help: String
    var onSelect: @MainActor (String) -> Void

    @State private var isOpen = false

    var body: some View {
        Button {
            isOpen = true
        } label: {
            ComposerControlLabel(
                systemImage: systemImage,
                text: isCompact ? nil : label,
                tint: tint,
                isActive: isOpen,
                showsMenuIndicator: true
            )
        }
        .buttonStyle(.glass)
        .fixedSize(horizontal: false, vertical: true)
        .help(help)
        .accessibilityLabel(help)
        .accessibilityValue(label)
        .popover(isPresented: $isOpen, arrowEdge: .top) {
            ComposerOptionList(
                options: options,
                footnote: footnote,
                selection: selection,
                heading: heading,
                onSelect: onSelect,
                onClose: { isOpen = false }
            )
        }
    }

    private var label: String {
        ComposerOption.label(for: selection, in: options)
    }
}
