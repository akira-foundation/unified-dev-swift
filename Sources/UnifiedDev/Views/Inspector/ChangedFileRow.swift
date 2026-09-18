import SwiftUI
import AppKit
import Core

struct ChangedFileRow: View, Equatable {
    nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.file == rhs.file
            && lhs.isSelected == rhs.isSelected
            && lhs.isViewed == rhs.isViewed
            && lhs.fullPath == rhs.fullPath
            && lhs.depth == rhs.depth
            && lhs.revertBlocker == rhs.revertBlocker
    }

    var file: ChangedFile
    var isSelected: Bool
    var isViewed: Bool = false
    var fullPath: String
    var depth: Int = 0
    var revertBlocker: String?
    var onSelect: () -> Void
    var onRevert: () -> Void
    var onOpenPage: @MainActor () -> Void
    var onSplitPage: @MainActor (SplitAxis) -> Void
    var onSetViewed: @MainActor (Bool) -> Void = { _ in }

    @Environment(\.isOnEmphasizedSelection) private var isOnSelection

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: InspectorLayout.gap) {
                glyph
                Text(file.filename)
                    .font(Typo.body)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .opacity(isViewed && !isOnSelection ? InspectorLayout.viewedOpacity : 1)
                Spacer(minLength: Metrics.spacingSmall)
                if isViewed {
                    Image(systemName: "checkmark.circle.fill")
                        .font(Typo.micro)
                        .imageScale(.small)
                        .foregroundStyle(isOnSelection ? Palette.selectedEmphasizedText : Palette.positive)
                        .accessibilityLabel("Viewed")
                }
                if file.isBinary {
                    Chip(text: "bin")
                } else {
                    DiffStatLabel(
                        additions: file.additions,
                        deletions: file.deletions,
                        compact: true
                    )
                }
                Image(systemName: isSelected ? "chevron.down" : "chevron.right")
                    .font(Typo.micro)
                    .imageScale(.small)
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
            .treeIndent(depth: depth)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(HoverQuickLook(url: URL(fileURLWithPath: fullPath)))
        .fileDrag(path: fullPath)
        .contextMenu {
            Button(ReviewedMarkAction(isViewed: isViewed).title) { onSetViewed(!isViewed) }
            Divider()
            OpenInItems(target: .file(fullPath))
            Button("Reveal in Finder") { Reveal.inFinder(fullPath) }
            LocalPageItems(path: fullPath, open: onOpenPage, split: onSplitPage)
            Button("Copy path", action: copyPath)
            Divider()
            RevertMenuItems(
                entry: FileBarControls.revertMenuEntry(filename: file.filename, blocker: revertBlocker),
                action: onRevert
            )
        }
        .help(file.path)
        .accessibilityInputLabels([file.filename])
        .accessibilityValue(isViewed ? "Viewed" : "")
    }

    private var glyph: some View {
        Text(file.change.rawValue)
            .font(Typo.codeTiny)
            .foregroundStyle(tint)
            .frame(width: InspectorLayout.glyphWidth, height: InspectorLayout.glyphWidth)
            .background(
                isOnSelection
                    ? Palette.selectedEmphasizedText.opacity(0.2)
                    : tint.opacity(InspectorLayout.tintOpacity),
                in: RoundedRectangle(cornerRadius: Metrics.cornerSmall)
            )
            .accessibilityLabel(Self.description(of: file.change))
    }

    private var tint: Color {
        guard !isOnSelection else { return Palette.selectedEmphasizedText }

        return switch file.change {
        case .added, .untracked: Palette.positive
        case .deleted: Palette.negative
        case .modified: Palette.warning
        case .renamed, .copied: Palette.accent(beside: [.positive, .negative, .warning])
        }
    }

    private static func description(of change: ChangedFile.Change) -> String {
        switch change {
        case .added: "Added"
        case .untracked: "Untracked"
        case .deleted: "Deleted"
        case .modified: "Modified"
        case .renamed: "Renamed"
        case .copied: "Copied"
        }
    }

    private func copyPath() {
        Clipboard.copy(file.path)
    }
}
