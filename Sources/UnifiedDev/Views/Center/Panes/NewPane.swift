import SwiftUI
import Core

@MainActor
enum NewPane {
    static func open(
        _ kind: PaneKind,
        in model: WorkspaceModel,
        url: String = "",
        title: String? = nil,
        directory: String = "",
        place: @escaping @MainActor (PaneContent) -> Void
    ) {
        switch kind {
        case .chat:
            Task {
                guard let content = await model.createChat(title: title) else { return }
                place(content)
            }

        case .terminal:
            let tab = CenterTabStore.shared.add(
                kind: .terminal, workspaceID: model.workspace.id, title: title,
                directory: directory
            )
            place(.tool(tab.id))

        case .browser:
            let tab = CenterTabStore.shared.add(
                kind: .browser, workspaceID: model.workspace.id, url: url, title: title
            )
            place(.tool(tab.id))
        }
    }
}
