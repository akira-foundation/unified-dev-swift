import SwiftUI
import Core

struct RepoSettingsSaveBar: View {
    @Bindable var model: RepoSettingsModel
    @Environment(AppModel.self) private var app

    var body: some View {
        HStack(spacing: Metrics.gutter) {
            status
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: Metrics.spacingSmall)

            Button("Revert File Changes", action: model.revert)
                .disabled(!model.isDirty && !model.hasExternalChange)

            Button("Save Files") {
                save()
            }
            .keyboardShortcut("s", modifiers: .command)
            .buttonStyle(.borderedProminent)
            .tint(Palette.controlAccent)
            .disabled(!model.isDirty)
        }
        .padding(.horizontal, Metrics.pane)
        .padding(.vertical, Metrics.inset)
        .background(Palette.surface)
        .focusedValue(
            \.saveAction,
            SaveAction(subject: "project settings", isEnabled: model.isDirty) {
                save()
            }
        )
    }

    private func save() {
        Task {
            guard await model.save() else { return }
            app.refreshSettings(for: model.repo.id, savedPaths: model.savedPaths)
        }
    }

    @ViewBuilder
    private var status: some View {
        if let error = model.saveError {
            Label(error, systemImage: "exclamationmark.triangle.fill")
                .font(Typo.caption)
                .foregroundStyle(Palette.negative)
        } else if model.hasExternalChange {
            Label(
                "These settings changed on disk while you were editing them. Save Files keeps your edits. Revert File Changes loads the new version.",
                systemImage: "arrow.triangle.2.circlepath"
            )
            .font(Typo.caption)
            .foregroundStyle(Palette.warning)
        } else if model.isDirty {
            Text("Unsaved repository changes: \(destinations).")
                .font(Typo.caption)
                .foregroundStyle(Palette.textSecondary)
        } else if !model.savedPaths.isEmpty {
            Label("Saved to \(saved).", systemImage: "checkmark.circle.fill")
                .font(Typo.caption)
                .foregroundStyle(Palette.positive)
        } else {
            Text("Repository changes need Save Files.")
                .font(Typo.caption)
                .foregroundStyle(Palette.textSecondary)
        }
    }

    private var destinations: String {
        list(model.pendingDestinations)
    }

    private var saved: String {
        list(model.savedPaths)
    }

    private func list(_ paths: [String]) -> String {
        let names = paths.map { path -> String in
            path.hasPrefix(model.repo.path + "/")
                ? String(path.dropFirst(model.repo.path.count + 1))
                : (path as NSString).abbreviatingWithTildeInPath
        }
        return names.isEmpty ? "the repository" : names.joined(separator: " and ")
    }
}
