import Core

@MainActor
struct TranscriptPaneMemory {
    let model: WorkspaceModel
    let pane: String

    func remembered(session: SessionID) -> TranscriptPaneState? {
        model.panePosition(pane: pane, session: session)
    }

    func restorePlace(session: SessionID) async {
        guard remembered(session: session) == nil,
              let place = try? await model.store?.transcriptPlace(sessionID: session),
              remembered(session: session) == nil
        else { return }
        model.rememberPanePosition(TranscriptPaneState(place: place), pane: pane, session: session)
    }

    func remember(_ state: TranscriptPaneState, session: SessionID) {
        let earlier = remembered(session: session)?.place
        model.rememberPanePosition(state, pane: pane, session: session)
        guard let place = state.place, place != earlier else { return }
        model.writeTranscriptPlace(place, session: session)
    }
}
