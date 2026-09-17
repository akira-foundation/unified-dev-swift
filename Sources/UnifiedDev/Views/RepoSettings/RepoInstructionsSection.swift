import SwiftUI
import Core

struct RepoInstructionsSection: View {
    @Bindable var model: RepoSettingsModel

    var body: some View {
        Section {
            RepoInstructionsField(
                model: model,
                subject: .merge,
                title: "Merging",
                summary: "Extra instructions for merging pull requests, such as your preferred merge method.",
                placeholder: "Squash unless the branch is a stack.",
                text: $model.draft.mergeInstructions
            )

            RepoInstructionsField(
                model: model,
                subject: .fixConflicts,
                title: "Merge conflicts",
                summary: "Extra instructions for resolving and pushing merge conflicts.",
                placeholder: "Regenerate the lock file rather than resolving it by hand.",
                text: $model.draft.conflictInstructions
            )
            DisclosureGroup("How instructions are applied") {
                VStack(alignment: .leading, spacing: Metrics.spacing) {
                    Text("Saved instructions apply to every workspace in this project, including existing ones. Commit the settings file to share them with your team.")
                    Text("Unified Dev attaches these instructions alongside its built-in merge and conflict-resolution steps. Empty fields add nothing.")
                }
                .settingsFootnote()
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        } header: {
            Text("Project instructions")
        }
    }
}

struct RepoInstructionsField: View {
    let model: RepoSettingsModel
    let subject: ProjectInstructions.Subject
    let title: String
    let summary: String
    var placeholder = ""
    @Binding var text: String

    private static let editorHeight: CGFloat = 96

    private static let focusRingWidth: CGFloat = 2

    @FocusState private var isFocused: Bool

    @Environment(\.controlActiveState) private var activeState

    private var isRingVisible: Bool { isFocused && activeState.showsFocusRing }

    private var overridingFile: String? { model.instructionFiles[subject] }

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.spacing) {
            HStack(alignment: .firstTextBaseline, spacing: Metrics.gutter) {
                Text(title)
                    .font(Typo.labelEmphasis)
                    .foregroundStyle(Palette.textPrimary)

                Spacer(minLength: Metrics.spacingSmall)

                SettingsDestinationLabel(
                    model: model, key: ProjectInstructions.settingsKey(for: subject)
                )
            }

            if let overridingFile {
                Label(
                    "\(overridingFile) overrides this field while the file contains instructions.",
                    systemImage: "exclamationmark.triangle"
                )
                .font(Typo.caption)
                .foregroundStyle(Palette.warning)
                .fixedSize(horizontal: false, vertical: true)
            }

            editor

            Text(summary)
                .font(Typo.caption)
                .foregroundStyle(Palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .multilineTextAlignment(.leading)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, Metrics.spacingSmall)
    }

    private var editor: some View {
        TextEditor(text: $text)
            .font(Typo.body)
            .scrollContentBackground(.hidden)
            .padding(Metrics.spacingSmall)
            .frame(minHeight: Self.editorHeight)
            .focused($isFocused)
            .background(Palette.surfaceSunken, in: RoundedRectangle(cornerRadius: Metrics.cornerSmall))
            .overlay {
                RoundedRectangle(cornerRadius: Metrics.cornerSmall)
                    .strokeBorder(
                        isRingVisible ? Palette.focusRing : Palette.border,
                        lineWidth: isRingVisible ? Self.focusRingWidth : Metrics.outline
                    )
            }
            .overlay(alignment: .topLeading) {
                if text.isEmpty {
                    Text(placeholder)
                        .font(Typo.body)
                        .foregroundStyle(Palette.textTertiary)
                        .padding(Metrics.spacingSmall)
                        .padding(.leading, Metrics.spacingTight)
                        .allowsHitTesting(false)
                }
            }
            .accessibilityLabel("Instructions for \(title.lowercased())")
    }
}
