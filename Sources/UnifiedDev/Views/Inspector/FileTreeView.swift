import SwiftUI
import Core

struct FileTreeView: View {
    let model: WorkspaceModel

    @Binding var query: String

    @State private var expanded: Set<String> = []
    @State private var selection: String?
    @State private var revealPath: String?

    @State private var filtered: FileTreeFilter.Outcome?
    @State private var filterOpen: Set<String> = []

    @State private var rows: [FileTreeRowItem] = []
    @State private var changedPaths: Set<String> = []
    @State private var highlightedPaths: Set<String> = []
    @State private var previewURL: URL?
    @State private var keyboardArm = 0
    @State private var rowTitles: [String] = []
    @State private var keyboard = ListKeyboard()
    @State private var hasKeyboard = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private struct LoadID: Hashable {
        var workspaceID: WorkspaceID
        var workspacePath: String
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                tree
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .onChange(of: selection) { _, path in
                        guard hasKeyboard, let path else { return }
                        proxy.scrollTo(path)
                    }
                    .onChange(of: revealPath) { _, path in
                        if let path { proxy.scrollTo(path, anchor: .center) }
                    }
                    .onChange(of: rows) { _, rows in
                        if let revealPath, rows.contains(where: { $0.id == revealPath }) {
                            proxy.scrollTo(revealPath, anchor: .center)
                        }
                    }
                    .onScrollPhaseChange { _, phase in
                        if phase == .tracking || phase == .interacting || phase == .decelerating { revealPath = nil }
                    }
            }
            .listKeyboard(
                hasKeyboard: $hasKeyboard,
                previewing: previewURL,
                armToken: keyboardArm,
                onKey: handle
            )
        }
        .task(id: LoadID(workspaceID: model.workspace.id, workspacePath: model.workspace.path)) {
            expanded = Set(UserDefaults.standard.stringArray(forKey: expansionKey) ?? [])
            selection = nil
            revealPath = nil
            query = ""
            await model.refreshFileTree()
            guard !Task.isCancelled else { return }
            if let path = FileReview.activePath(in: model), let ancestors = FileTreeNode.ancestors(of: path, in: model.fileTree) {
                expanded.formUnion(ancestors)
                rebuildRows()
                selection = path
                revealPath = path
            } else {
                rebuildRows()
            }
        }
        .onChange(of: expanded) { _, paths in
            UserDefaults.standard.set(paths.sorted(), forKey: expansionKey)
        }
        .onChange(of: model.fileTree, initial: true) { _, _ in rebuildRows() }
        .onChange(of: query) { _, _ in
            revealPath = nil
            rebuildRows()
        }
        .onChange(of: hasKeyboard) { _, focused in
            if !focused { keyboard.forgetTyping() }
        }
        .onChange(of: selection) { _, path in
            previewURL = path.flatMap { QuickLookTarget.url(for: fullPath($0)) }
        }
        .onChange(of: model.changedFiles, initial: true) { _, files in
            changedPaths = Set(files.map(\.path))
            highlightedPaths = FileTreeChanges.highlightedPaths(for: changedPaths)
        }
    }

    private var expansionKey: String { "fileTree.expanded." + model.workspace.id.rawValue }

    @ViewBuilder
    private var tree: some View {
        if !model.hasReadFileTree {
            LoadingView("Listing the worktree")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if model.fileTree.isEmpty {
            EmptyStateView(
                glyph: "folder",
                title: "Nothing tracked",
                message: "Git knows about no files in this worktree yet."
            )
        } else if let filtered, filtered.isEmpty {
            EmptyStateView(
                glyph: "magnifyingglass",
                title: "No files match",
                message: "Nothing in this worktree matches \(query)."
            )
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(rows) { item in
                        row(item)
                    }
                }
                .padding(.vertical, InspectorLayout.tight)
            }
        }
    }

    private func row(_ item: FileTreeRowItem) -> some View {
        let path = item.node.path

        return HoverRow(isSelected: selection == path, isFocused: hasKeyboard) {
            FileTreeRow(
                item: item,
                isExpanded: openFolders.contains(path),
                isChanged: changedPaths.contains(path),
                containsChanges: highlightedPaths.contains(path),
                fullPath: fullPath(path),
                action: { activate(item.node) },
                onOpenTerminal: { FolderTerminalTab.open(folder: fullPath(path), in: model) },
                onOpenPage: { BrowserTab.openFile(fullPath(path), in: model) },
                onSplitPage: { BrowserTab.splitFile(fullPath(path), in: model, axis: $0) }
            )
            .equatable()
        }
        .background {
            if highlightedPaths.contains(path), selection != path {
                RoundedRectangle(cornerRadius: Metrics.corner)
                    .fill(Palette.positive.opacity(0.10))
            }
        }
        .padding(.horizontal, Metrics.spacingSmall)
    }

    private var children: [String: [FileTreeNode]] {
        filtered?.children ?? model.fileTree
    }

    private var openFolders: Set<String> {
        filtered == nil ? expanded : filterOpen
    }

    private func activate(_ node: FileTreeNode) {
        revealPath = nil
        keyboardArm += 1

        guard node.isDirectory else {
            selection = node.path
            if changedPaths.contains(node.path) { model.selectedFilePath = node.path }
            FileReview.open(path: node.path, in: model)
            return
        }

        toggle(node)
    }

    private func rebuildRows() {
        let outcome = FileTreeFilter.apply(
            to: model.fileTree, needle: FileNeedle.canonical(query)
        )
        filtered = outcome
        filterOpen = outcome?.open ?? []
        adopt(FileTreeRowItem.flatten(
            children: outcome?.children ?? model.fileTree,
            expanded: outcome?.open ?? expanded
        ))
    }

    private func adopt(_ items: [FileTreeRowItem]) {
        rows = items
        rowTitles = items.map(\.node.name)

        if let selection, !items.contains(where: { $0.node.path == selection }) {
            self.selection = nil
        }
    }

    private func handle(key: ListKey) -> Bool {
        revealPath = nil
        let index = selection.flatMap { path in rows.firstIndex { $0.node.path == path } }

        if key == .left || key == .right {
            switch TreeNavigation.step(key, at: index, in: treeShape) {
            case .expand(let row), .collapse(let row):
                toggle(rows[row].node)
            case .move(let row):
                selection = rows[row].node.path
            case .none:
                break
            }
            return true
        }

        switch keyboard.outcome(for: key, titles: rowTitles, current: index) {
        case .move(let row):
            selection = rows[row].node.path
            return true
        case .activate:
            guard let index else { return false }
            activate(rows[index].node)
            return true
        case .handled:
            return true
        case .ignored:
            return false
        }
    }

    private var treeShape: [TreeRow] {
        let open = openFolders
        return rows.map {
            TreeRow(
                depth: $0.depth,
                isDirectory: $0.node.isDirectory,
                isExpanded: open.contains($0.node.path)
            )
        }
    }

    private func toggle(_ node: FileTreeNode) {
        revealPath = nil
        var opened = openFolders
        if opened.contains(node.path) {
            opened.remove(node.path)
        } else {
            opened.insert(node.path)
        }

        let items = FileTreeRowItem.flatten(children: children, expanded: opened)
        let motion = TreeDisclosureMotion.rows(
            changing: abs(items.count - rows.count), reduceMotion: reduceMotion
        )

        selection = node.path

        withAnimation(motion.animation) {
            if filtered == nil {
                expanded = opened
            } else {
                filterOpen = opened
            }
            adopt(items)
        }
    }

    private func escape() {
        guard query.isEmpty else {
            query = ""
            return
        }
        enterTree()
    }

    private func enterTree() {
        if selection == nil,
           let first = rows.first(where: { !$0.node.isDirectory }) ?? rows.first {
            selection = first.node.path
        }
        keyboardArm += 1
    }

    private func fullPath(_ relative: String) -> String {
        (model.workspace.path as NSString).appendingPathComponent(relative)
    }
}
