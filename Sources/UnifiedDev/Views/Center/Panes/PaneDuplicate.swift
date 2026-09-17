import SwiftUI
import Core

@MainActor
enum PaneDuplicate {
    static func open(
        _ content: PaneContent,
        in model: WorkspaceModel,
        place: @escaping @MainActor (PaneContent) -> Void
    ) {
        let tab = tab(for: content, in: model)
        switch PaneSplit.duplicating(content, tabKind: tab?.kind) {
        case .sameContent:
            place(content)

        case .freshTerminal:
            let folder = FolderTerminalTab.target(folder: tab?.directory ?? "", in: model)
            NewPane.open(
                .terminal, in: model, title: folder?.title,
                directory: folder?.directory ?? "", place: place
            )

        case .freshBrowser:
            NewPane.open(.browser, in: model, url: tab?.url ?? "", place: place)

        case .nothing:
            return
        }
    }

    static func canOpen(_ content: PaneContent, in model: WorkspaceModel) -> Bool {
        PaneSplit.duplicating(content, tabKind: tab(for: content, in: model)?.kind).opensAPane
    }

    static func sameAgainKind(_ content: PaneContent, in model: WorkspaceModel) -> PaneKind? {
        PaneSplit.duplicating(content, tabKind: tab(for: content, in: model)?.kind).sameAgainKind
    }

    private static func tab(for content: PaneContent, in model: WorkspaceModel) -> CenterTab? {
        guard case .tool(let tabID) = content else { return nil }
        return CenterTabStore.shared.tabs(for: model.workspace.id).first { $0.id == tabID }
    }
}
