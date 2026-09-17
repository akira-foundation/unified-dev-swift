import SwiftUI
import Core

struct NewTabMenu: View {
    @Bindable var model: WorkspaceModel

    private var store: WorkspaceTabsStore { .shared }

    var body: some View {
        Menu {
            Button(PaneKind.chat.title, systemImage: PaneKind.chat.symbol, action: newChat)
                .keyboardShortcut("t", modifiers: .command)
            Button(PaneKind.terminal.title, systemImage: PaneKind.terminal.symbol, action: newTerminal)
                .keyboardShortcut("t", modifiers: [.command, .shift])
            Button(PaneKind.browser.title, systemImage: PaneKind.browser.symbol, action: newBrowser)
                .keyboardShortcut("b", modifiers: [.command, .shift])
            Divider()
            Button("Changes", systemImage: "doc.text") { FileReview.open(in: model) }
                .keyboardShortcut("d", modifiers: [.command, .shift])
            Button(CenterTab.notesTitle, systemImage: "note.text") { WorkspaceNotes.open(in: model) }
            runScriptItems
        } label: {
            Label("New tab", systemImage: "plus")
                .labelStyle(.iconOnly)
        }
        .onHover { if $0 { model.refreshSettings() } }
        .help("New tab in this workspace")
        .accessibilityLabel("New tab in this workspace")
    }

    @ViewBuilder
    private var runScriptItems: some View {
        let scripts = model.settings.runScripts
        if !scripts.isEmpty {
            let running = runningScripts()
            Divider()
            Section("Run Scripts") {
                ForEach(scripts) { script in
                    let item = RunScriptMenuItem.make(
                        script: script,
                        isRunning: running.contains(script.id),
                        missingFile: missingFile(of: script)
                    )
                    Button {
                        RunScriptLauncher.shared.pick(script, in: model)
                    } label: {
                        Label {
                            Text(verbatim: item.title)
                        } icon: {
                            Image(systemName: RunScriptGlyph.symbol(for: script.icon))
                        }
                        Text(verbatim: item.subtitle)
                    }
                    .disabled(!item.isEnabled)
                }
            }
        }
    }

    private func runningScripts() -> Set<String> {
        Set(CenterTabStore.shared.tabs(for: model.workspace.id).compactMap { tab in
            RunScriptLauncher.shared.isRunning(tab) ? tab.runScriptID : nil
        })
    }

    private func missingFile(of script: RunScript) -> String? {
        guard let file = model.settings.scriptFiles[.run(script.id)], file.isMissing else { return nil }
        return file.path
    }

    private func newChat() {
        NewPane.open(.chat, in: model) { store.select($0, in: model) }
    }

    private func newTerminal() {
        NewPane.open(.terminal, in: model) { store.select($0, in: model) }
    }

    private func newBrowser() {
        Task {
            let address = await model.browserAddress()
            NewPane.open(.browser, in: model, url: address) { store.select($0, in: model) }
        }
    }
}
