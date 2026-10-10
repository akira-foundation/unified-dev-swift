import Foundation
import Testing
@testable import Core

@Suite("What a table compares to know an answered question changed height")
struct AgentQuestionRowKeyTests {
    private func key(
        decision: String? = nil,
        answers: [String: String] = [:],
        isExpanded: Bool = false
    ) -> TranscriptContentKey {
        TranscriptRowContentKey(
            id: 7,
            seq: 12,
            kind: .permissionAsk,
            isError: false,
            durationMS: nil,
            resultPayloadCount: nil,
            permissionDecision: decision,
            permissionNote: "",
            permissionAnswers: answers,
            parentToolUseID: nil,
            isExpanded: isExpanded,
            subagentActions: nil,
            subagentHasRun: false,
            wasStopped: false,
            wasRecovered: false,
            closesTranscript: false,
            stillRunning: nil,
            suggestion: nil
        ).contentKey
    }

    @Test("answering the question is a different key, so the row is measured again at its new height")
    func answering() {
        #expect(key() != key(decision: PermissionDecision.answeredName, answers: ["q1": "Postgres"]))
    }

    @Test("reopening the card by hand is a different key from the closed line")
    func reopening() {
        let closed = key(decision: PermissionDecision.answeredName, answers: ["q1": "Postgres"])
        let open = key(decision: PermissionDecision.answeredName, answers: ["q1": "Postgres"], isExpanded: true)

        #expect(closed != open)
    }

    @Test("the answer the closed line prints is part of what the table compares")
    func theAnswerItself() {
        let postgres = key(decision: PermissionDecision.answeredName, answers: ["q1": "Postgres"])
        let sqlite = key(decision: PermissionDecision.answeredName, answers: ["q1": "SQLite"])
        let kept = key(decision: PermissionDecision.answeredName)

        #expect(postgres != sqlite)
        #expect(postgres != kept)
    }

    @Test("a question that did not change is the same key, so the row is not measured again")
    func unchanged() {
        #expect(key() == key())
        #expect(
            key(decision: PermissionDecision.answeredName, answers: ["q1": "Postgres"])
                == key(decision: PermissionDecision.answeredName, answers: ["q1": "Postgres"])
        )
    }
}
