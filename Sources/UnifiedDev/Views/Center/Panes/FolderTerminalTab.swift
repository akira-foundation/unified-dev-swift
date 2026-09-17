import SwiftUI
import Core

@MainActor
enum FolderTerminalTab {
    static func open(folder: String, in model: WorkspaceModel) {
        guard let target = target(folder: folder, in: model) else { return }
        NewPane.open(
            .terminal, in: model, title: target.title, directory: target.directory
        ) { content in
            WorkspaceTabsStore.shared.reveal(content, in: model)
        }
    }

    static func target(folder: String, in model: WorkspaceModel) -> FolderTerminal.Target? {
        let taken = CenterTabStore.shared.tabs(for: model.workspace.id)
            .filter { $0.kind == .terminal }
            .map(\.title)
        return FolderTerminal.target(folder: folder, taken: taken)
    }
}
