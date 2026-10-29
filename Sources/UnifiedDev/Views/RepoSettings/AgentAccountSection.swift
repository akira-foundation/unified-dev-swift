import SwiftUI
import Core

struct AgentAccountSection: View {
    var level: AgentAccountOptions.Scope
    var target: AccountScope

    @Environment(AppModel.self) private var app

    @State private var options: AgentAccountOptions?
    @State private var failure: String?

    var body: some View {
        AgentAccountRows(options: options, failure: failure, onPick: choose)
            .task(id: app.accountFingerprint(for: target)) {
                options = await app.accountOptions(level: level, in: target)
            }
    }

    private func choose(_ pick: AgentAccountOptions.Pick) {
        guard let options, pick != options.selected, pick != .unavailable,
              let entry = options.entry(for: pick) else { return }
        failure = nil
        Task {
            failure = await app.chooseAccount(entry.home, level: level, in: target)
        }
    }
}

struct AgentAccountRows: View {
    var options: AgentAccountOptions?
    var failure: String?
    var onPick: (AgentAccountOptions.Pick) -> Void

    var body: some View {
        Section {
            SettingsRow("Account") {
                if let options {
                    picker(options)
                } else {
                    ProgressView().controlSize(.small)
                }
            }
        } header: {
            Text("Agent account")
        } footer: {
            footer
        }
    }

    private func picker(_ options: AgentAccountOptions) -> some View {
        Picker("Account", selection: Binding(get: { options.selected }, set: { onPick($0) })) {
            Text(options.inherit.title).tag(options.inherit.pick)

            ForEach(options.groups) { group in
                Section(group.title) {
                    ForEach(group.entries) { entry in
                        Text(entry.title).tag(entry.pick)
                    }
                }
            }

            if let unavailable = options.unavailable {
                Text(unavailable.title).tag(unavailable.pick)
            }
        }
        .labelsHidden()
        .fixedSize()
    }

    @ViewBuilder
    private var footer: some View {
        if let failure {
            Text(failure)
                .font(Typo.caption)
                .foregroundStyle(Palette.negative)
        }
        if failure == nil, let options {
            Text(options.footer)
                .font(Typo.caption)
                .foregroundStyle(options.warns ? Palette.warning : Palette.textSecondary)
        }
    }
}
