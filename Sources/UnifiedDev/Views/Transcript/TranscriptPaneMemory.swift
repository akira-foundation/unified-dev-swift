import Core

@MainActor
struct TranscriptPaneMemory {
    let model: WorkspaceModel
    let pane: String

    func remembered(session: SessionID) -> TranscriptPaneState? {
        model.panePosition(pane: pane, session: session)
    }

    func remember(_ state: TranscriptPaneState, session: SessionID) {
        model.rememberPanePosition(state, pane: pane, session: session)
    }
}
