import SwiftUI
import Core

struct MergeMethodSettingsSection: View {
    @Environment(AppModel.self) private var app

    @State private var method = MergeMethodChoice.fallback
    @State private var isLoaded = false
    @State private var saving: Task<Void, Never>?

    var body: some View {
        Section {
            Picker("Default merge method", selection: binding) {
                ForEach(MergeMethodChoice.offered, id: \.self) { offered in
                    Text(offered.label).tag(offered)
                }
            }
            .disabled(!isLoaded)
        } header: {
            Text("Pull requests")
        } footer: {
            Text("The Merge button uses this in every project that has not chosen its own method.")
                .settingsFootnote()
        }
        .task {
            guard let store = app.store else { return }
            method = await MergeMethodChoice.appDefault(from: store)
            isLoaded = true
        }
    }

    private var binding: Binding<GitHub.MergeMethod> {
        Binding(
            get: { method },
            set: { chosen in
                method = chosen
                guard let store = app.store else { return }
                saving = Task { [saving] in
                    await saving?.value
                    await MergeMethodChoice.saveAppDefault(chosen, to: store)
                }
            }
        )
    }
}
