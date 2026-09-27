import SwiftUI
import Core

struct ComposerPresetMenu<Label: View>: View {
    var presets: [ModelPreset]
    var matched: ModelPreset?
    var onPreset: @MainActor (ModelPreset) -> Void
    var onCustom: @MainActor () -> Void
    var onManage: @MainActor () -> Void
    @ViewBuilder var label: () -> Label

    var body: some View {
        Menu {
            Section("Presets") {
                ForEach(presets) { preset in
                    Toggle(isOn: Binding(
                        get: { matched?.id == preset.id },
                        set: { _ in MainActor.assumeIsolated { onPreset(preset) } }
                    )) {
                        Text(preset.name)
                        Text(preset.permissionMode.label(on: preset.backend))
                    }
                }
            }

            Divider()

            Button("Custom\u{2026}") { onCustom() }

            Divider()

            Button("Manage Presets\u{2026}") { onManage() }
        } label: {
            label()
        }
        .menuStyle(.button)
        .menuIndicator(.hidden)
    }
}
