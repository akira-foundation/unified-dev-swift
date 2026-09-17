import Foundation
import Core

@MainActor
struct ComposerSessionEditor {
    var transcript: TranscriptModel
    var model: WorkspaceModel?

    func apply(implementationMode: PermissionMode? = nil, _ change: (inout Session) -> Void) {
        var session = transcript.session
        change(&session)
        session.updatedAt = Date.now
        transcript.session = session

        if let model, let index = model.sessions.firstIndex(where: { $0.id == session.id }) {
            model.sessions[index] = session
        }
        Task {
            await transcript.updatePreferences(
                title: session.title,
                model: session.model,
                effort: session.effort,
                permissionMode: session.permissionMode,
                interactionMode: session.interactionMode,
                implementationMode: implementationMode,
                agentKind: session.agentKind
            )
        }
    }
}
