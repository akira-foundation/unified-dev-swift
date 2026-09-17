import SwiftUI
import AppKit
import Core

struct FileTreeRow: View, Equatable {
    nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.item.node == rhs.item.node
            && lhs.item.depth == rhs.item.depth
            && lhs.isExpanded == rhs.isExpanded
            && lhs.isChanged == rhs.isChanged
            && lhs.containsChanges == rhs.containsChanges
            && lhs.fullPath == rhs.fullPath
    }

    var item: FileTreeRowItem
    var isExpanded: Bool
    var isChanged: Bool
    var containsChanges = false
    var fullPath: String
    var action: () -> Void
    var onOpenTerminal: () -> Void
    var onOpenPage: @MainActor () -> Void
    var onSplitPage: @MainActor (SplitAxis) -> Void

    @Environment(\.isOnEmphasizedSelection) private var isOnSelection

    private static let changedDotSize: CGFloat = 5

    var body: some View {
        Button(action: action) {
            HStack(spacing: InspectorLayout.gap) {
                FileTreeIcon(name: item.node.name, isDirectory: item.node.isDirectory, isExpanded: isExpanded)
                Text(item.node.name)
                    .font(Typo.body)
                    .foregroundStyle(item.node.isDirectory ? .secondary : .primary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer(minLength: 0)
                if isChanged {
                    Circle()
                        .fill(isOnSelection ? Palette.selectedEmphasizedText : Palette.warning)
                        .frame(width: Self.changedDotSize, height: Self.changedDotSize)
                        .accessibilityLabel("Changed")
                }
            }
            .treeIndent(depth: item.depth)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background {
            if !item.node.isDirectory { HoverQuickLook(url: URL(fileURLWithPath: fullPath)) }
        }
        .fileDrag(path: fullPath)
        .contextMenu {
            OpenInItems(target: item.node.isDirectory ? .folder(fullPath) : .file(fullPath))
            Button("Reveal in Finder") { Reveal.inFinder(fullPath) }
            if FolderTerminal.canOpen(folder: fullPath) {
                Button(FolderTerminal.menuTitle, action: onOpenTerminal)
            }
            LocalPageItems(path: fullPath, open: onOpenPage, split: onSplitPage)
            Button("Copy path", action: copyPath)
        }
        .help(item.node.path)
        .accessibilityValue(disclosureState)
        .accessibilityInputLabels([item.node.name])
    }

    private var disclosureState: String {
        guard item.node.isDirectory else { return "" }
        let state = isExpanded ? "Expanded" : "Collapsed"
        return containsChanges ? "\(state), contains changed files" : state
    }

    private func copyPath() {
        Clipboard.copy(item.node.path)
    }
}
