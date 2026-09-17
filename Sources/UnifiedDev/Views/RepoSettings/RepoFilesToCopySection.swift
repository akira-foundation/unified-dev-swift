import SwiftUI
import Foundation
import Core

struct RepoFilesToCopySection: View {
    @Bindable var model: RepoSettingsModel

    private static let editorHeight: CGFloat = 74
    private static let listedMatches = 12

    private static let focusRingWidth: CGFloat = 2

    @FocusState private var isFocused: Bool

    @Environment(\.controlActiveState) private var activeState

    private var isRingVisible: Bool { isFocused && activeState.showsFocusRing }

    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: Metrics.gutter) {
                editor
                Divider()
                resolution
            }
            .padding(.vertical, Metrics.spacingSmall)
        } header: {
            Text("Files to copy")
        } footer: {
            VStack(alignment: .leading, spacing: Metrics.spacingTight) {
                Text("One pattern per line, relative to the project folder. Copied into every new workspace, and into a restored one, because git does not bring ignored files back.")
                SettingsDestinationLabel(model: model, key: .filesToCopy)
            }
            .font(Typo.caption)
            .foregroundStyle(Palette.textSecondary)
        }
    }

    private var editor: some View {
        TextEditor(text: $model.draft.filesToCopyText)
            .font(Typo.codeSmall)
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
            .accessibilityLabel("Patterns of files to copy into a new workspace")
            .onChange(of: model.draft.filesToCopyText) { _, _ in model.scheduleResolve() }
    }

    @ViewBuilder
    private var resolution: some View {
        VStack(alignment: .leading, spacing: Metrics.spacing) {
            HStack(spacing: Metrics.spacingWide) {
                summary
                Spacer(minLength: Metrics.spacingSmall)
                Button("Refresh", systemImage: "arrow.clockwise") {
                    model.scheduleResolve(immediately: true)
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
                .foregroundStyle(Palette.textSecondary)
                .help("Look at the project folder again")
            }

            if !model.plan.matches.isEmpty {
                matchList
            }

            if !model.plan.unmatchedPatterns.isEmpty {
                Label(
                    "Matches nothing yet: \(model.plan.unmatchedPatterns.joined(separator: ", "))",
                    systemImage: "questionmark.circle"
                )
                .font(Typo.caption)
                .foregroundStyle(Palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    @ViewBuilder
    private var summary: some View {
        if !model.plan.repoExists {
            Label("The project folder is not on disk, so nothing can be resolved.", systemImage: "exclamationmark.triangle.fill")
                .font(Typo.caption)
                .foregroundStyle(Palette.warning)
                .fixedSize(horizontal: false, vertical: true)
        } else {
            Text(summaryText)
                .font(Typo.caption)
                .foregroundStyle(model.plan.fileCount == 0 ? Palette.warning : Palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .opacity(model.isResolving ? 0.5 : 1)
        }
    }

    private var summaryText: String {
        let plan = model.plan
        guard plan.fileCount > 0 else {
            return model.globs.isEmpty
                ? "Nothing will be copied. A new workspace starts with only what git checks out."
                : "No file matches, so nothing will be copied."
        }
        let files = plan.fileCount == 1 ? "1 file" : "\(plan.fileCount) files"
        var text = "\(files) will be copied from \((model.repo.path as NSString).abbreviatingWithTildeInPath)"
        if plan.directoryCount > 0 {
            let folders = plan.directoryCount == 1 ? "1 folder" : "\(plan.directoryCount) folders"
            text += ", and \(folders) matched but will be skipped"
        }
        return text + "."
    }

    private var matchList: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(model.plan.matches.prefix(Self.listedMatches)) { match in
                HStack(spacing: Metrics.gutter) {
                    Image(systemName: match.isDirectory ? "folder" : "doc")
                        .foregroundStyle(match.isDirectory ? Palette.warning : Palette.textTertiary)
                        .frame(width: Metrics.glyph)

                    Text(match.path)
                        .font(Typo.codeSmall)
                        .foregroundStyle(match.isDirectory ? Palette.textSecondary : Palette.textPrimary)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    Spacer(minLength: Metrics.spacingSmall)

                    if match.isDirectory {
                        Text("folder, not copied")
                            .font(Typo.caption)
                            .foregroundStyle(Palette.textSecondary)
                    }
                }
                .padding(.horizontal, Metrics.inset)
                .padding(.vertical, Metrics.spacingSmall)
            }

            if remainder > 0 {
                Text("and \(remainder) more")
                    .font(Typo.caption)
                    .foregroundStyle(Palette.textSecondary)
                    .padding(.horizontal, Metrics.inset)
                    .padding(.vertical, Metrics.spacingSmall)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.surfaceSunken, in: RoundedRectangle(cornerRadius: Metrics.cornerSmall))
        .overlay {
            RoundedRectangle(cornerRadius: Metrics.cornerSmall)
                .strokeBorder(Palette.border, lineWidth: Metrics.outline)
        }
    }

    private var remainder: Int {
        let total = model.plan.fileCount + model.plan.directoryCount
        return max(0, total - Self.listedMatches)
    }
}
