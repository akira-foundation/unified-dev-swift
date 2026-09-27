import SwiftUI
import Core

struct ComposerPresetSaveRow: View {
    var matchedPreset: ModelPreset?
    var suggestedName: String
    var onSave: @MainActor (String) -> Void

    @State private var name: String?
    @FocusState private var isNamingFocused: Bool

    var body: some View {
        Group {
            if let name {
                naming(name)
            } else {
                saved
            }
        }
        .padding(.horizontal, Metrics.gutter)
        .padding(.vertical, Metrics.inset)
    }

    @ViewBuilder
    private var saved: some View {
        if let matchedPreset {
            Text("Saved as preset \u{201C}\(matchedPreset.name)\u{201D}")
                .font(Typo.label)
                .foregroundStyle(Palette.textSecondary)
                .lineLimit(1)
                .frame(maxWidth: .infinity, minHeight: Metrics.rowHeight, alignment: .leading)
        } else {
            Button("Save as Preset\u{2026}") {
                name = suggestedName
                isNamingFocused = true
            }
            .linkButton()
            .font(Typo.label)
            .frame(maxWidth: .infinity, minHeight: Metrics.rowHeight, alignment: .leading)
        }
    }

    private func naming(_ current: String) -> some View {
        HStack(spacing: Metrics.spacing) {
            TextField("Preset name", text: Binding(get: { current }, set: { name = $0 }))
                .textFieldStyle(.roundedBorder)
                .controlSize(.small)
                .focused($isNamingFocused)
                .onSubmit(save)
                .onExitCommand { name = nil }

            Button("Cancel") { name = nil }
                .controlSize(.small)
            Button("Save", action: save)
                .controlSize(.small)
                .keyboardShortcut(.defaultAction)
                .disabled(ModelPreset.cleanName(current) == nil)
        }
    }

    private func save() {
        guard let name, ModelPreset.cleanName(name) != nil else { return }
        onSave(name)
        self.name = nil
    }
}
