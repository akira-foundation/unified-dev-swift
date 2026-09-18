import SwiftUI
import Core

struct RepoScriptsSection: View {
    @Bindable var model: RepoSettingsModel

    var body: some View {
        Group {
            scriptSection
            runSection
        }
    }

    private var scriptSection: some View {
        Section {
            RepoScriptField(
                model: model,
                location: .setup,
                key: .setupScript,
                title: "Setup script",
                summary: "Runs once, in the new worktree, before the first message is sent. A workspace whose setup fails is created but marked failed.",
                placeholder: "#!/bin/zsh",
                text: $model.draft.setupScript
            )

            RepoScriptField(
                model: model,
                location: .archive,
                key: .archiveScript,
                title: "Archive script",
                summary: "Runs in the worktree just before it is removed. Undo whatever setup did outside the folder here: a Valet site, a database, a container.",
                placeholder: "#!/bin/zsh",
                text: $model.draft.archiveScript
            )
            DisclosureGroup("Execution details and variables") {
                VStack(alignment: .leading, spacing: Metrics.spacingTight) {
                    Text("Scripts run in the workspace folder without an interactive shell. Files use their shebang; inline commands use zsh.")
                    Text(Self.variables)
                        .font(Typo.codeTiny)
                    Text(Self.urlFile)
                    Text(Self.alias)
                    Text(Self.rerun)
                }
                .settingsFootnote()
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private static let variables = "\(WorkspaceManager.environmentPrefix)_"
        + "{WORKSPACE_NAME, WORKSPACE_ID, WORKSPACE_PATH, PROJECT_NAME, ROOT_PATH, "
        + "DEFAULT_BRANCH, PORT, IS_LOCAL, URL_FILE}"

    private static let urlFile = "Write an address to $"
        + "\(WorkspaceManager.environmentPrefix)_URL_FILE and this workspace's browser panes open "
        + "on it, for a site whose hostname only the setup script knows."

    private static let alias = "Each is also set as "
        + "\(WorkspaceManager.deprecatedEnvironmentPrefix)_*, for scripts written for Conductor."

    private static let rerun =
        "To run the setup script again in a workspace, use Run Setup Again on the workspace's own "
        + "row, in the Workspace menu, or on the failed setup row in its transcript."

    private var runSection: some View {
        Section {
            ForEach(model.draft.runScripts) { script in
                RepoRunScriptRow(
                    model: model,
                    script: Binding(
                        get: { model.draft.runScript(id: script.id) ?? script },
                        set: { model.draft.updateRunScript($0) }
                    )
                ) {
                    model.draft.removeRunScript(id: script.id)
                }
            }

            HStack {
                Button("Add Run Script", systemImage: "plus") {
                    model.draft.runScripts.append(DraftRunScript(name: "Run", command: ""))
                }
                Spacer()
            }

            Picker("When several workspaces are open", selection: $model.draft.runMode) {
                Text("Only one may run at a time").tag("nonconcurrent")
                Text("They may all run at once").tag("concurrent")
            }
        } header: {
            Text("Run scripts")
        } footer: {
            VStack(alignment: .leading, spacing: Metrics.spacingTight) {
                Text("Start these from the Workspace menu. Limit them to one workspace when they share a port or database.")
                SettingsDestinationLabel(model: model, key: .runScripts)
            }
            .font(Typo.caption)
            .foregroundStyle(Palette.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct RepoScriptField: View {
    let model: RepoSettingsModel
    let location: ScriptLocation
    let key: SettingsKey
    let title: String
    let summary: String
    var placeholder = ""
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.spacing) {
            HStack(alignment: .firstTextBaseline, spacing: Metrics.gutter) {
                Text(title)
                    .font(Typo.labelEmphasis)
                    .foregroundStyle(Palette.textPrimary)

                Spacer(minLength: Metrics.spacingSmall)

                ScriptDestinationLabel(model: model, location: location, key: key, script: text)
            }

            if let missing = model.missingScriptFile(for: location) {
                MissingScriptNote(path: missing)
            }

            ScriptEditor(text: $text, placeholder: placeholder)
                .accessibilityLabel(title)

            Text(summary)
                .font(Typo.caption)
                .foregroundStyle(Palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .multilineTextAlignment(.leading)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, Metrics.spacingSmall)
    }
}

struct ScriptDestinationLabel: View {
    let model: RepoSettingsModel
    let location: ScriptLocation
    let key: SettingsKey
    let script: String

    var body: some View {
        if let file {
            Text(text(for: file))
                .font(Typo.caption)
                .foregroundStyle(isMoving ? Palette.warning : Palette.textSecondary)
                .lineLimit(1)
                .truncationMode(.middle)
                .help(help(for: file))
        } else {
            SettingsDestinationLabel(model: model, key: key)
        }
    }

    private var file: String? { model.scriptFile(for: location, script: script) }

    private var isMoving: Bool { model.loaded.scriptFiles[location] == nil }

    private func text(for file: String) -> String {
        guard model.phase == .idle else {
            return SettingsSaveLabel.text(destination: file, phase: model.phase)
        }
        return isMoving ? "Moving into \(file)" : "Saved to \(file)"
    }

    private func help(for file: String) -> String {
        let settings = short(model.destination(for: key))
        guard isMoving else {
            return "Saved to \(file), which \(settings) names as this script."
        }
        return """
            A script with a shebang, or with more than one line, is a program rather than a \
            setting. Saving writes it to \(file), makes it executable, and leaves \(settings) \
            naming that path instead of holding the text. It can then be run, and linted, on its \
            own.
            """
    }

    private func short(_ path: String) -> String {
        path.hasPrefix(model.repo.path + "/")
            ? String(path.dropFirst(model.repo.path.count + 1))
            : (path as NSString).abbreviatingWithTildeInPath
    }
}

struct MissingScriptNote: View {
    let path: String

    var body: some View {
        Label(
            "\(path) is named here but is not on disk. The script is skipped rather than failed, and anything typed below is written back to that path.",
            systemImage: "exclamationmark.triangle"
        )
        .font(Typo.caption)
        .foregroundStyle(Palette.warning)
        .fixedSize(horizontal: false, vertical: true)
    }
}

struct RepoRunScriptRow: View {
    let model: RepoSettingsModel
    @Binding var script: DraftRunScript
    let onRemove: () -> Void

    private static let nameWidth: CGFloat = 180

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.spacing) {
            HStack(spacing: Metrics.gutter) {
                TextField("", text: $script.name, prompt: Text("Name"))
                    .textFieldStyle(.roundedBorder)
                    .labelsHidden()
                    .frame(width: Self.nameWidth)

                if let storage {
                    Text(storage)
                        .font(Typo.codeTiny)
                        .foregroundStyle(Palette.textTertiary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Spacer(minLength: Metrics.spacingSmall)

                Button("Remove this run script", systemImage: "minus.circle", action: onRemove)
                    .labelStyle(.iconOnly)
                    .buttonStyle(.borderless)
                    .foregroundStyle(Palette.textSecondary)
                    .help("Remove this run script")
            }

            if !script.key.isEmpty, let missing = model.missingScriptFile(for: .run(script.key)) {
                MissingScriptNote(path: missing)
            }

            ScriptEditor(
                text: $script.command,
                placeholder: "Command",
                minimumHeight: 40,
                maximumHeight: 160
            )
            .accessibilityLabel("Command for \(script.name)")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, Metrics.spacingTight)
    }
}

private extension RepoRunScriptRow {
    var storage: String? {
        guard !script.key.isEmpty else { return nil }
        if let file = model.scriptFile(for: .run(script.key), script: script.command) {
            return file
        }
        return "scripts.run.\(script.key)"
    }
}
