import SwiftUI
import Core

struct AskTabStrip: View {
    @Environment(AppModel.self) private var app
    @State private var renaming: SessionID?
    @Namespace private var selection

    var body: some View {
        TabStrip(selection: app.ask.selectedID) {
            EmptyView()
        } tabs: {
            HStack(spacing: 0) {
                ForEach(app.ask.sessions) { chat in
                    TabItemView(
                        title: app.ask.title(for: chat), icon: .symbol(PaneGlyph.chat),
                        isActive: app.ask.selectedID == chat.id,
                        isRunning: app.ask.isRunning(chat.id),
                        isRenaming: renaming == chat.id,
                        editableTitle: app.ask.title(for: chat), canClose: true,
                        closeTitle: "Close conversation",
                        onSelect: { Task { await app.ask.select(chat.id) } },
                        onStartRename: { renaming = chat.id },
                        onCommitRename: { title in
                            renaming = nil
                            Task { await app.ask.rename(chat.id, title: title) }
                        },
                        onCancelRename: { renaming = nil },
                        onClose: { app.ask.requestClose(chat.id) },
                        namespace: selection
                    )
                    .id(chat.id)
                }
            }
        } append: {
            Button { Task { await app.ask.newConversation() } } label: {
                Image(systemName: "plus")
            }
            .buttonStyle(.plain)
            .foregroundStyle(Palette.textSecondary)
            .padding(.horizontal, Metrics.inset)
            .help("New Ask Unified Dev conversation")
            .accessibilityLabel("New Ask Unified Dev conversation")
        } trailing: {
            EmptyView()
        }
    }
}
