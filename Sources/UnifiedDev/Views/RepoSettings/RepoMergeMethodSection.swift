import SwiftUI
import Core

struct RepoMergeMethodSection: View {
    let repo: Repo

    @Environment(AppModel.self) private var app

    @State private var choice: GitHub.MergeMethod?
    @State private var appDefault = MergeMethodChoice.fallback
    @State private var isLoaded = false
    @State private var saving: Task<Void, Never>?

    var body: some View {
        Section {
            Picker("Merge method", selection: binding) {
                Text("App default (\(appDefault.label))").tag(GitHub.MergeMethod?.none)
                Divider()
                ForEach(MergeMethodChoice.offered, id: \.self) { offered in
                    Text(offered.label).tag(GitHub.MergeMethod?.some(offered))
                }
            }
            .disabled(!isLoaded)
        } header: {
            Text("Pull requests")
        } footer: {
            Text("Choosing a method from the Merge button also changes it here.")
                .settingsFootnote()
        }
        .task(id: repo.id) {
            guard let store = app.store else { return }
            let changes = store.changes(of: [.settings])
            await load(from: store)
            isLoaded = true
            for await _ in changes {
                await load(from: store)
            }
        }
    }

    private func load(from store: Store) async {
        appDefault = await MergeMethodChoice.appDefault(from: store)
        choice = await MergeMethodChoice.projectChoice(repoID: repo.id, from: store)
    }

    private var binding: Binding<GitHub.MergeMethod?> {
        Binding(
            get: { choice },
            set: { chosen in
                choice = chosen
                guard let store = app.store else { return }
                saving = Task { [saving, repoID = repo.id] in
                    await saving?.value
                    await MergeMethodChoice.save(chosen, repoID: repoID, to: store)
                }
            }
        )
    }
}
