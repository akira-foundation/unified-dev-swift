import SwiftUI
import Core

struct DetailColumn: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        if !app.isLoaded {
            LoadingView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            switch app.selection {
            case .home:
                HomeView()
            case .ask:
                AskView()
            case .workspace(let id):
                workspace(id)
            case .crew(let workspaceID, let sessionID):
                crew(sessionID, in: workspaceID)
            case .subagent(let workspaceID, let subagentID):
                subagent(.live(subagentID), in: workspaceID)
            case .subagentCall(let workspaceID, let toolUseID):
                subagent(.recorded(toolUseID: toolUseID), in: workspaceID)
            case .archived(let id):
                archived(id)
            }
        }
    }

    @ViewBuilder
    private func subagent(_ target: SubagentRunLink.Target, in workspaceID: WorkspaceID) -> some View {
        if let model = app.existingModel(for: workspaceID) {
            SubagentOutputView(model: model, target: target)
        } else {
            workspace(workspaceID)
        }
    }

    @ViewBuilder
    private func crew(_ id: SessionID, in workspaceID: WorkspaceID) -> some View {
        if let model = app.existingModel(for: workspaceID) {
            CrewChatColumn(model: model, sessionID: id)
        } else {
            workspace(workspaceID)
        }
    }

    @ViewBuilder
    private func archived(_ id: WorkspaceID) -> some View {
        if let model = app.existingModel(for: id) {
            ArchivedWorkspaceView(model: model)
        } else {
            HomeView()
        }
    }

    @ViewBuilder
    private func workspace(_ id: WorkspaceID) -> some View {
        if let model = app.existingModel(for: id) {
            let _ = SwitchTrace.mark("column.body", workspace: id)
            CenterColumnView(model: model)
                .disabled(app.isArchiving(id))
                .overlay {
                    if app.isArchiving(id) { ArchiveInteractionShield() }
                }
        } else {
            HomeView()
        }
    }
}

private struct CrewChatColumn: View {
    var model: WorkspaceModel
    var sessionID: SessionID

    var body: some View {
        Group {
            if let transcript = model.existingTranscript(for: sessionID) {
                ChatPaneView(transcript: transcript, model: model, pane: "crew:" + sessionID.rawValue)
            } else {
                Color.clear
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task(id: sessionID) {
            if !model.hasReadSessions { await model.reloadSessions() }
            model.prepareTranscript(for: sessionID)
        }
    }
}
