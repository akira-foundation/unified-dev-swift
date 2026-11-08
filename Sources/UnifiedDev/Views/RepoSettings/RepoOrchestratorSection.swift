import SwiftUI
import Core

struct RepoOrchestratorSection: View {
    let repo: Repo

    @Environment(AppModel.self) private var app

    @State private var isOn = false
    @State private var isLoaded = false
    @State private var failure: String?
    @State private var saving: Task<Void, Never>?

    var body: some View {
        RepoOrchestratorRows(isOn: binding, isEnabled: isLoaded, failure: failure)
            .task(id: repo.id) {
                guard let store = app.store else { return }
                let changes = store.changes(of: [.settings])
                isOn = await OrchestratorUnaskedCommands.isOn(repoID: repo.id, in: store)
                isLoaded = true
                for await _ in changes {
                    isOn = await OrchestratorUnaskedCommands.isOn(repoID: repo.id, in: store)
                }
            }
    }

    private var binding: Binding<Bool> {
        Binding(
            get: { isOn },
            set: { chosen in
                isOn = chosen
                failure = nil
                guard let store = app.store else { return }
                saving = Task { [saving, repoID = repo.id] in
                    await saving?.value
                    do {
                        try await OrchestratorUnaskedCommands.save(chosen, repoID: repoID, to: store)
                    } catch {
                        isOn = await OrchestratorUnaskedCommands.isOn(repoID: repoID, in: store)
                        failure = OrchestratorUnaskedCommands.saveFailure
                    }
                }
            }
        )
    }
}

struct RepoOrchestratorRows: View {
    @Binding var isOn: Bool
    var isEnabled: Bool
    var failure: String?

    var body: some View {
        Section {
            LabeledContent(OrchestratorUnaskedCommands.settingTitle) {
                Toggle(OrchestratorUnaskedCommands.settingTitle, isOn: $isOn)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .disabled(!isEnabled)
            }
        } header: {
            Text(OrchestratorUnaskedCommands.settingHeader)
        } footer: {
            VStack(alignment: .leading, spacing: Metrics.spacingSmall) {
                Text(OrchestratorUnaskedCommands.caveat)
                    .settingsFootnote()
                if let failure {
                    Text(failure)
                        .font(Typo.caption)
                        .foregroundStyle(Palette.negative)
                }
            }
        }
    }
}
