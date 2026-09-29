import SwiftUI
import Core

struct SidebarNavRow: View {
    var title: String
    var icon: String

    var body: some View {
        Label {
            Text(title)
        } icon: {
            Image(systemName: icon)
        }
    }
}

struct SidebarAskRow: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        HStack(spacing: 0) {
            SidebarNavRow(title: AskConversation.title, icon: PaneGlyph.chat)
            Spacer(minLength: Metrics.spacingSmall)
            if let status = app.askStatus {
                WorkspaceStatusGlyph(status: status, isOnSelection: false)
            }
        }
    }
}

extension View {
    func selectedRowInk(isEmphasized: Bool) -> some View {
        environment(\.backgroundProminence, isEmphasized ? .increased : .standard)
            .foregroundStyle(isEmphasized ? Palette.selectedEmphasizedText : Palette.textPrimary)
    }
}
