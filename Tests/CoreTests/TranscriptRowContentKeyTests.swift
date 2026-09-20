import Testing
import Foundation
@testable import Core

@Suite("What a table compares to know a suggestion row moved")
struct TranscriptRowContentKeyTests {
    private func suggestion(_ state: WorkSuggestion.State) -> WorkSuggestion {
        WorkSuggestion(
            stored: WorkSuggestionID("suggestion-1"),
            workspaceID: WorkspaceID("workspace-1"),
            sessionID: SessionID("chat-1"),
            anchorSeq: 12,
            title: "Keep the last row",
            why: "The parser drops the last row.",
            prompt: "Keep the last row.",
            target: .sameProject,
            state: state,
            failure: nil,
            createdAt: Date(timeIntervalSince1970: 1),
            decidedAt: nil
        )
    }

    private func key(_ card: WorkSuggestion?) -> TranscriptContentKey {
        TranscriptRowContentKey(
            id: 42,
            seq: 12,
            kind: .suggestion,
            isError: false,
            durationMS: nil,
            resultPayloadCount: nil,
            permissionDecision: nil,
            permissionNote: "",
            parentToolUseID: nil,
            isExpanded: false,
            subagentActions: nil,
            subagentHasRun: false,
            wasStopped: false,
            wasRecovered: false,
            closesTranscript: false,
            stillRunning: nil,
            suggestion: card
        ).contentKey
    }

    @Test("a card arriving for a row is a different key, so the row is measured again")
    func theCardArriving() {
        #expect(key(nil) != key(suggestion(.pending)))
    }

    @Test("a card that is being started is a different key from one still pending")
    func theCardStarting() {
        #expect(key(suggestion(.pending)) != key(suggestion(.starting)))
    }

    @Test("a card that started a workspace is a different key from one still pending")
    func theCardDecided() {
        let started = WorkSuggestion.State.startedWorkspace(WorkspaceID("workspace-2"), name: "Importer")
        #expect(key(suggestion(.pending)) != key(suggestion(started)))
        #expect(key(suggestion(.pending)) != key(suggestion(.dismissed)))
    }

    @Test("the same card is the same key")
    func theSameCard() {
        #expect(key(suggestion(.pending)) == key(suggestion(.pending)))
        #expect(key(nil) == key(nil))
    }
}
