import SwiftUI
import Core

struct AgentAccountsSection: View {
    let panel: AgentAccountPanel
    let activity: AgentAccountsModel.Activity
    let canSignIn: Bool
    let onAdd: () -> Void
    let onRemove: (AgentAccountPanel.Row) -> Void

    var body: some View {
        ForEach(panel.rows) { row in
            AgentAccountRowSection(row: row, onRemove: onRemove)
        }

        Section {
            switch panel.offer {
            case .available:
                HStack(spacing: Metrics.gutter) {
                    Button("Add account…", action: onAdd)
                        .disabled(!canSignIn || activity == .confirmingSignIn)
                    if let progress {
                        ProgressView()
                            .controlSize(.small)
                            .accessibilityHidden(true)
                        Text(progress)
                            .settingsFootnote()
                    }
                }
            case .unavailable(let reason):
                Label {
                    Text(reason)
                        .settingsFootnote()
                } icon: {
                    Image(systemName: "info.circle")
                        .foregroundStyle(Palette.textTertiary)
                }
            }
        } footer: {
            VStack(alignment: .leading, spacing: Metrics.spacingSmall) {
                if let footer = panel.footer {
                    Text(footer)
                        .settingsFootnote()
                }
                if panel.offer.isAvailable {
                    Text("Sign in with another \(panel.provider.label) account. Each project can then choose which account runs.")
                        .settingsFootnote()
                }
            }
        }
    }

    private var progress: String? {
        switch activity {
        case .idle: nil
        case .checkingSessions: "Checking sessions"
        case .confirmingSignIn: "Confirming the sign-in"
        }
    }
}

private struct AgentAccountRowSection: View {
    let row: AgentAccountPanel.Row
    let onRemove: (AgentAccountPanel.Row) -> Void

    var body: some View {
        Section {
            ForEach(row.fields) { field in
                SettingsRow(field.label) {
                    Text(field.value)
                        .foregroundStyle(field.isKnown ? Palette.textSecondary : Palette.textTertiary)
                        .textSelection(.enabled)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }

            if !row.isDefault, let note = row.note {
                Text(note)
                    .font(Typo.caption)
                    .foregroundStyle(row.warns ? Palette.warning : Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let removal = row.removal {
                Button("\(removal.actionTitle)…", role: .destructive) { onRemove(row) }
            }
        } header: {
            Text(row.title)
        } footer: {
            if row.isDefault, let note = row.note {
                Text(note).settingsFootnote()
            }
        }
    }
}
