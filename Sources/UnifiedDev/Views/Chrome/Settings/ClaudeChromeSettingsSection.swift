import SwiftUI
import Core

struct ClaudeChromeSettingsSection: View {
    @Environment(AppModel.self) private var app
    @State private var isOn = false
    @State private var failure: String?

    private var choice: Binding<Bool> {
        Binding(get: { isOn }, set: { value in
            isOn = value
            Task { await store(value) }
        })
    }

    var body: some View {
        Section {
            Toggle("Use Claude in Chrome", isOn: choice)
            if let failure { Text(failure).foregroundStyle(.red) }
        } footer: {
            Text("Gives Claude Code agents the Claude in Chrome tools, which open tabs and act in your own Chrome with its sign ins. Needs the Claude extension in Chrome and a claude.ai sign in. A chat whose agent is already running picks it up when that agent next starts.")
                .settingsFootnote()
        }
        .task {
            guard let store = app.store else { return }
            do {
                isOn = ClaudeChrome.isEnabled(try await store.setting(ClaudeChrome.settingKey))
            } catch { failure = error.localizedDescription }
        }
    }

    private func store(_ value: Bool) async {
        do {
            try await app.store?.setSetting(ClaudeChrome.settingKey, ClaudeChrome.storedValue(value))
            failure = nil
        } catch { failure = error.localizedDescription }
    }
}
