import Testing
import Foundation
@testable import Core

@Suite struct BackendChangeTests {
    @Test func aChatThatHasSpokenForksRatherThanChanging() {
        #expect(BackendChange.decide(from: .claudeCode, to: .codex, hasSpoken: true) == .fork(.codex))
        #expect(BackendChange.decide(from: .codex, to: .claudeCode, hasSpoken: true) == .fork(.claudeCode))
    }

    @Test func anEmptyChatSimplyChanges() {
        #expect(BackendChange.decide(from: .claudeCode, to: .codex, hasSpoken: false)
            == .changeInPlace(.codex))
    }

    @Test func choosingTheBackendItIsAlreadyOnDoesNothing() {
        #expect(BackendChange.decide(from: .codex, to: .codex, hasSpoken: true) == .unchanged)
        #expect(BackendChange.decide(from: .codex, to: .codex, hasSpoken: false) == .unchanged)
    }

    @Test func aBackendWithNoRunnerIsNotADestination() {
        #expect(BackendChange.decide(from: .claudeCode, to: .cursor, hasSpoken: false) == .unchanged)
        #expect(BackendChange.decide(from: .claudeCode, to: .openCode, hasSpoken: true) == .unchanged)
    }

    @Test func aChatWhoseHistoryHasNotBeenReadCountsAsHavingSpoken() {
        #expect(BackendChange.hasSpoken(rowCount: 0, agentSessionID: nil, isTranscriptLoaded: false))
        #expect(BackendChange.decide(
            from: .claudeCode,
            to: .codex,
            hasSpoken: BackendChange.hasSpoken(
                rowCount: 0, agentSessionID: nil, isTranscriptLoaded: false
            )
        ) == .fork(.codex))
    }

    @Test func aThreadIdIsProofOnItsOwn() {
        #expect(BackendChange.hasSpoken(
            rowCount: 0, agentSessionID: "abc-123", isTranscriptLoaded: true
        ))
        #expect(!BackendChange.hasSpoken(rowCount: 0, agentSessionID: "", isTranscriptLoaded: true))
    }

    @Test func aRowOnScreenIsProofOnItsOwn() {
        #expect(BackendChange.hasSpoken(rowCount: 3, agentSessionID: nil, isTranscriptLoaded: true))
    }

    @Test func aReadAndEmptyChatHasNotSpoken() {
        #expect(!BackendChange.hasSpoken(rowCount: 0, agentSessionID: nil, isTranscriptLoaded: true))
        #expect(BackendChange.decide(
            from: .claudeCode,
            to: .codex,
            hasSpoken: BackendChange.hasSpoken(
                rowCount: 0, agentSessionID: nil, isTranscriptLoaded: true
            )
        ) == .changeInPlace(.codex))
    }

    @Test func theForkNoticeNamesTheNewChatAndTheBackendThatStayed() {
        let message = BackendChange.forkNotice(title: "Fix the parser on Codex", from: .claudeCode)
        let text = NoticeText(message)
        #expect(text.plain.contains("Fix the parser on Codex"))
        #expect(text.plain.contains("Claude Code"))
        #expect(!text.reason.isEmpty)
        #expect(text.fact.contains { $0.isMachine && $0.text == "Fix the parser on Codex" })
    }

    @Test func theReplacementNoticeSaysNothingIsLost() {
        let text = NoticeText(BackendChange.replacementNotice(from: .claudeCode, to: .codex))
        #expect(text.plain.contains("Codex"))
        #expect(text.plain.contains("Claude Code"))
        #expect(text.plain.contains("archived"))
        #expect(!text.reason.isEmpty)
    }

    @Test func aForkThatCouldNotBeMadeSaysSoRatherThanNothing() {
        let text = NoticeText(BackendChange.forkFailureNotice(to: .codex))
        #expect(text.plain.contains("Codex"))
        #expect(text.plain.contains("unchanged"))
    }

    @Test func aForkIsNamedSoTheStripCanTellThemApart() {
        #expect(BackendChange.forkedTitle("Fix the parser", to: .codex) == "Fix the parser on Codex")
        #expect(BackendChange.forkedTitle("", to: .codex) == "New session on Codex")
        #expect(BackendChange.forkedTitle("Fix the parser on Codex", to: .claudeCode)
            == "Fix the parser on Claude Code")
    }
}
