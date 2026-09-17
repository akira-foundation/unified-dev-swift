import SwiftUI
import AppKit
import Core

struct ChangedFolderRow: View, Equatable {
    nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.name == rhs.name
            && lhs.path == rhs.path
            && lhs.isExpanded == rhs.isExpanded
            && lhs.depth == rhs.depth
            && lhs.fullPath == rhs.fullPath
    }

    var name: String
    var path: String
    var isExpanded: Bool
    var depth: Int
    var fullPath: String
    var action: () -> Void
    var onOpenTerminal: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
            HStack(spacing: InspectorLayout.gap) {
                Image(systemName: "chevron.right")
                    .font(Typo.micro)
                    .imageScale(.small)
                    .foregroundStyle(.tertiary)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    .animation(
                        TreeDisclosureMotion.chevron(reduceMotion: reduceMotion).animation,
                        value: isExpanded
                    )
                    .frame(width: InspectorLayout.glyphWidth, alignment: .leading)
                    .accessibilityHidden(true)
                Text(name)
                    .font(Typo.body)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.head)
                Spacer(minLength: 0)
            }
            .treeIndent(depth: depth)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Reveal in Finder") { Reveal.inFinder(fullPath) }
            OpenInItems(target: .folder(fullPath))
            if FolderTerminal.canOpen(folder: fullPath) {
                Button(FolderTerminal.menuTitle, action: onOpenTerminal)
            }
            Button("Copy path", action: copyPath)
        }
        .help(path)
        .accessibilityLabel(name)
        .accessibilityValue(isExpanded ? "Expanded" : "Collapsed")
        .accessibilityInputLabels([name])
    }

    private func copyPath() {
        Clipboard.copy(path)
    }
}
