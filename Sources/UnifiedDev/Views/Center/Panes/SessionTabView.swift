import SwiftUI
import Core

struct SessionTabView: View {
    var session: Session
    var agentGlyph: String?
    var isActive: Bool
    var isRunning: Bool
    var isRenaming: Bool
    var canClose: Bool
    var onSelect: @MainActor () -> Void
    var onStartRename: @MainActor () -> Void
    var onCommitRename: @MainActor (String) -> Void
    var onCancelRename: @MainActor () -> Void
    var onClose: @MainActor () -> Void
    var onSplitRight: (@MainActor () -> Void)?
    var onSplitDown: (@MainActor () -> Void)?
    var onMoveLeft: (@MainActor () -> Void)?
    var onMoveRight: (@MainActor () -> Void)?
    var namespace: Namespace.ID

    var body: some View {
        TabItemView(
            title: session.title.isEmpty ? PaneNaming.untitledChat : session.title,
            icon: .symbol(PaneGlyph.chatTab(agentMark: agentGlyph)),
            isActive: isActive,
            isRunning: isRunning,
            surface: TabPane.content.surface,
            isRenaming: isRenaming,
            editableTitle: session.title,
            canClose: canClose,
            closeTitle: "Close session",
            onSelect: onSelect,
            onStartRename: onStartRename,
            onCommitRename: onCommitRename,
            onCancelRename: onCancelRename,
            onClose: onClose,
            onSplitRight: onSplitRight,
            onSplitDown: onSplitDown,
            onMoveLeft: onMoveLeft,
            onMoveRight: onMoveRight,
            namespace: namespace
        )
    }
}
