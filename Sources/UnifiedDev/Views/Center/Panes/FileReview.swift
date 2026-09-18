import SwiftUI
import Core

@MainActor
enum FileReview {
    static func open(path: String, in model: WorkspaceModel, focusing: Bool = false) {
        let location = CodeLocation.parse(path)
        if location.path != path { open(location: location, in: model); return }
        SourceEditorState.file((model.workspace.path as NSString).appendingPathComponent(path)).diffRequest = nil
        SourceNavigation.shared.visit(location, in: model)
        if model.changedFiles.contains(where: { $0.path == path }) { model.selectedFilePath = path }
        show(path: path, in: model, focusing: focusing)
        if let tab = CenterTabStore.shared.review(for: model.workspace.id) {
            CenterTabStore.shared.setShowsAllFiles(false, for: tab)
        }
    }

    static func open(location: CodeLocation, in model: WorkspaceModel, recording: Bool = true) {
        var location = location
        location.path = location.displayPath(relativeTo: model.workspace.path)
        if recording { SourceNavigation.shared.visit(location, in: model) }
        let absolute = (location.path as NSString).isAbsolutePath ? location.path
            : (model.workspace.path as NSString).appendingPathComponent(location.path)
        SourceEditorState.file(absolute).go(to: location)
        show(path: location.path, in: model, focusing: true)
        if let tab = CenterTabStore.shared.review(for: model.workspace.id) {
            CenterTabStore.shared.setShowsAllFiles(false, for: tab)
        }
        if model.changedFiles.contains(where: { $0.path == location.path }) { model.selectedFilePath = location.path }
    }

    static func activePath(in model: WorkspaceModel) -> String? {
        let workspaceTabs = WorkspaceTabsStore.shared
        guard let selected = workspaceTabs.selectedTab(in: model) else { return nil }
        let layout = workspaceTabs.layout(of: selected)
        let panes = [layout.focus] + layout.panes.filter { $0 != layout.focus }
        let tabs = CenterTabStore.shared.tabs(for: model.workspace.id)
        for pane in panes {
            guard case let .tool(id) = workspaceTabs.content(of: pane, in: selected),
                  let tab = tabs.first(where: { $0.id == id && $0.kind == .review }) else { continue }
            let path = tab.showsAllFiles && !tab.isPinnedToPath ? model.selectedFilePath ?? tab.path : tab.path
            if !path.isEmpty { return CodeLocation(path: path).displayPath(relativeTo: model.workspace.path) }
        }
        return nil
    }

    static func openFromDiff(_ target: CodeLocation, in model: WorkspaceModel, newTab: Bool) async {
        var location = target
        location.path = location.displayPath(relativeTo: model.workspace.path)
        if !newTab, let file = model.reviewFiles.first(where: { $0.path == location.path }) {
            let patch = await model.patch(for: file)
            guard !Task.isCancelled else { return }
            if let diff = DiffDocument.parse(patch: patch, path: file.path), DiffDocument.contains(location, in: diff) {
                let absolute = (model.workspace.path as NSString).appendingPathComponent(location.path)
                let state = SourceEditorState.file(absolute)
                state.request = nil
                state.prefersEditing = false
                state.diffLine = location.line
                state.diffRequest = location
                state.diffRevision &+= 1
                SourceNavigation.shared.visit(location, in: model)
                model.selectedFilePath = location.path
                show(path: location.path, in: model, focusing: true)
                return
            }
        }
        openInNewTab(path: "\(location.path):\(location.line):\(location.column)", in: model)
    }

    private static func show(path: String, in model: WorkspaceModel, focusing: Bool) {
        let tab = CenterTabStore.shared.showReview(path: path, workspaceID: model.workspace.id)
        WorkspaceTabsStore.shared.reveal(.tool(tab.id), in: model, focusing: focusing)
    }

    static func openInNewTab(path: String, in model: WorkspaceModel) {
        let location = CodeLocation.parse(path)
        SourceNavigation.shared.visit(location, in: model)
        if location.path != path {
            let absolute = (location.path as NSString).isAbsolutePath ? location.path
                : (model.workspace.path as NSString).appendingPathComponent(location.path)
            SourceEditorState.file(absolute).go(to: location)
        }
        let tab = CenterTabStore.shared.openPinnedReview(path: location.path, workspaceID: model.workspace.id)
        WorkspaceTabsStore.shared.reveal(.tool(tab.id), in: model)
    }

    static func open(in model: WorkspaceModel) {
        let remembered = currentPath(in: model)
        let fallback = model.selectedFilePath ?? model.reviewFiles.first?.path
        show(
            path: remembered.flatMap { $0.isEmpty ? nil : $0 } ?? fallback ?? "",
            in: model,
            focusing: true
        )
    }

    static func currentPath(in model: WorkspaceModel) -> String? {
        let tab = CenterTabStore.shared.review(for: model.workspace.id)
        return tab?.showsAllFiles == true ? model.selectedFilePath ?? tab?.path : tab?.path
    }

    static func openAll(in model: WorkspaceModel) {
        setShowsAllFiles(true, in: model)
    }

    static func setShowsAllFiles(_ all: Bool, in model: WorkspaceModel) {
        let store = CenterTabStore.shared
        let remembered = store.review(for: model.workspace.id)?.path
        let candidates = [model.selectedFilePath, remembered].compactMap { $0 }
        let path = candidates.first { candidate in
            model.changedFiles.contains { $0.path == candidate }
        } ?? model.reviewFiles.first?.path ?? ""
        let tab = store.showReview(path: path, workspaceID: model.workspace.id)
        store.setShowsAllFiles(all, for: tab)
        WorkspaceTabsStore.shared.reveal(.tool(tab.id), in: model)
    }

    static func toggle(in model: WorkspaceModel) {
        let tabs = WorkspaceTabsStore.shared
        guard let tab = tabs.selectedTab(in: model) else { return open(in: model) }
        let pane = tabs.focusedPane(of: tab)

        if let review = CenterTabStore.shared.review(for: model.workspace.id),
           tabs.content(of: pane, in: tab) == .tool(review.id) {
            guard let session = model.activeSession ?? model.sessions.first else { return }
            tabs.replace(pane: pane, of: tab, with: .chat(session.id), in: model)
            return
        }
        open(in: model)
    }

    static func step(_ delta: Int, in model: WorkspaceModel) {
        let files = model.reviewFiles
        guard !files.isEmpty else { return }

        let current = currentPath(in: model)
        let index = files.firstIndex { $0.path == current }
        let next = index.map { ($0 + delta + files.count) % files.count } ?? 0

        select(path: files[next].path, in: model)
    }

    static func select(path: String, in model: WorkspaceModel) {
        model.selectedFilePath = path
        guard CenterTabStore.shared.review(for: model.workspace.id)?.showsAllFiles == true else {
            open(path: path, in: model)
            return
        }
        SourceEditorState.file((model.workspace.path as NSString).appendingPathComponent(path)).diffRequest = nil
        SourceNavigation.shared.visit(CodeLocation.parse(path), in: model)
        setShowsAllFiles(true, in: model)
    }
}
