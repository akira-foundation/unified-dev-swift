import SwiftUI
import Core

struct WorkspaceSettingsNotices: View {
    var model: WorkspaceModel

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var launcher: RunScriptLauncher { .shared }

    var body: some View {
        let ask = launcher.ask(for: model.workspace.id)
        let issues = SettingsIssuesNotice.make(issues: model.settings.issues)
            .flatMap { launcher.dismissedIssues.contains($0.signature) ? nil : $0 }

        VStack(spacing: 0) {
            if let ask {
                autostart(ask)
            }
            if let issues {
                settingsIssues(issues)
            }
        }
        .animation(reduceMotion ? nil : Motion.pane, value: ask)
        .animation(reduceMotion ? nil : Motion.pane, value: issues)
    }

    private func autostart(_ notice: RunScriptAutostartNotice) -> some View {
        WorkspaceNoticeStrip(symbol: "play.circle", tint: Palette.accent(beside: [.warning]), title: notice.title) {
            VStack(alignment: .leading, spacing: Metrics.spacingTight) {
                ForEach(notice.lines) { line in
                    commandLine(line)
                }
            }
        } actions: {
            Button("Not Now") { launcher.notNow(in: model) }
                .controlSize(.small)
            Button(notice.allowTitle) { Task { await launcher.allow(notice, in: model) } }
                .controlSize(.small)
                .buttonStyle(.borderedProminent)
        }
    }

    private func commandLine(_ line: RunScriptAutostartNotice.Line) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Metrics.spacing) {
            Text(verbatim: line.name)
                .font(Typo.captionEmphasis)
                .foregroundStyle(Palette.textPrimary)
                .lineLimit(1)
                .fixedSize()

            if let approved = line.approved {
                Text(verbatim: approved)
                    .font(Typo.codeSmall)
                    .foregroundStyle(Palette.textSecondary)
                    .strikethrough()
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .help(approved)
                Image(systemName: "arrow.right")
                    .imageScale(.small)
                    .foregroundStyle(Palette.textTertiary)
                    .accessibilityLabel("changed to")
            }

            Text(verbatim: line.command)
                .font(Typo.codeSmall)
                .foregroundStyle(Palette.textPrimary)
                .lineLimit(1)
                .truncationMode(.middle)
                .textSelection(.enabled)
                .help(line.command)
        }
    }

    private func settingsIssues(_ notice: SettingsIssuesNotice) -> some View {
        WorkspaceNoticeStrip(
            symbol: "exclamationmark.triangle", tint: Palette.warning, title: notice.title,
            onDismiss: { launcher.dismissIssues(notice) }
        ) {
            VStack(alignment: .leading, spacing: Metrics.spacingTight) {
                ForEach(Array(notice.messages.enumerated()), id: \.offset) { _, message in
                    Text(verbatim: message)
                        .font(Typo.caption)
                        .foregroundStyle(Palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                }
            }
        } actions: {
            Button("Open File") { SettingsFileOpener.open(notice.path, repo: model.workspace.repoID) }
                .controlSize(.small)
        }
    }
}
