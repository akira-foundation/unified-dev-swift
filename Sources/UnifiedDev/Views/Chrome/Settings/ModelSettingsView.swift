import SwiftUI
import Core

struct ModelSettingsView: View {
    @Binding var defaults: AppDefaults
    @State private var outputStyles = ComposerOutputStyleCatalog()

    var body: some View {
        Form {
            Section {
                SettingsRow("New sessions") {
                    ModelAndEffortPickers(
                        model: $defaults.model, effort: $defaults.effort, backend: $defaults.backend
                    )
                }
                SettingsRow("Reviews") {
                    ModelAndEffortPickers(
                        model: $defaults.reviewModel, effort: $defaults.reviewEffort,
                        backend: $defaults.reviewBackend
                    )
                }
            } header: {
                Text("Models")
            } footer: {
                Text("Each row selects a model and reasoning effort. Project model settings take priority. Existing sessions keep their settings.")
                    .settingsFootnote()
            }

            Section("New session behaviour") {
                Picker("Open new chats in", selection: $defaults.terminalChat) {
                    Text("Unified Dev chat").tag(false)
                    Text("CLI chat").tag(true)
                }
                Text("Used for new chats, panes and workspaces. CLI chat supports Claude Code and Codex; other agents use Unified Dev chat.")
                    .settingsFootnote()
                Toggle("Start in plan mode", isOn: $defaults.planMode)
                Toggle("Start in fast mode", isOn: $defaults.fastMode)
            }

            Section("Claude Code") {
                Picker(selection: $defaults.outputStyle) {
                    ForEach(outputStyles.options(includingCurrent: defaults.outputStyle)) { option in
                        Text(option.label).tag(option.id)
                    }
                } label: {
                    Text("Output style")
                    Text(outputStyles.detail(of: defaults.outputStyle) ?? "How new Claude Code sessions write.")
                }
            }

            Section {
                Picker("Context window", selection: $defaults.codexContextWindow) {
                    ForEach(CodexContextWindow.options(including: defaults.codexContextWindow), id: \.self) { tokens in
                        Text(CodexContextWindow.label(for: tokens)).tag(tokens)
                    }
                }
            } header: {
                Text("Codex")
            } footer: {
                Text("Overrides the context size reported to new Codex sessions. Use the model default unless you need a specific size.")
                    .settingsFootnote()
            }
        }
        .settingsForm()
        .task {
            ComposerModelCatalog.shared.load()
            await outputStyles.refreshIfStale(project: nil)
        }
    }
}

private struct ModelAndEffortPickers: View {
    @Binding var model: String
    @Binding var effort: String
    @Binding var backend: AgentKind

    private var catalog: ComposerModelCatalog { .shared }

    var body: some View {
        HStack(spacing: Metrics.gutter) {
            Picker("Model", selection: chosenModel) {
                ForEach(catalog.sections(includingCurrent: model, on: backend)) { section in
                    Section(section.title) {
                        ForEach(section.options) { option in
                            Text(option.label).tag(option.id)
                        }
                    }
                }
            }
            .labelsHidden()
            .fixedSize()

            Picker("Effort", selection: $effort) {
                ForEach(ComposerOption.adding([effort], to: efforts)) { option in
                    Text(option.label).tag(option.id)
                }
            }
            .labelsHidden()
            .fixedSize()
        }
    }

    private var efforts: [ComposerOption] {
        catalog.efforts(for: backend, model: model)
    }

    private var chosenModel: Binding<String> {
        Binding(get: { model }, set: { id in MainActor.assumeIsolated { choose(id) } })
    }

    private func choose(_ id: String) {
        let kind = catalog.backend(ofModel: id, current: backend)
        model = id
        backend = kind
        effort = catalog.resolvedEffort(effort, for: kind, model: id)
    }
}
