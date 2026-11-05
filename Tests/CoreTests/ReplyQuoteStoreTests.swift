import Foundation
import Testing
@testable import Core

@Suite(.scratchDirectory) struct ReplyQuoteStoreTests {
    private func quote(_ text: String, seq: Int? = nil) throws -> ReplyQuote {
        try #require(ReplyQuote(selection: text, sourceSeq: seq))
    }

    @Test func quotesComeBackInOrderAfterReopening() async throws {
        let store = try makeTestStore("reply-quotes-reopen")
        let session = try await store.upsert(AskConversation.newSession())
        let first = try quote("second in the alphabet", seq: 4)
        let second = try quote("first in the alphabet")
        try await store.add(first, sessionID: session.id)
        try await store.add(second, sessionID: session.id)

        let reopened = try Store(path: store.path)

        #expect(try await reopened.replyQuotes(sessionID: session.id) == [first, second])
    }

    @Test func quotesSurviveAnEmptyDraft() async throws {
        let store = try makeTestStore("reply-quotes-empty-draft")
        let session = try await store.upsert(AskConversation.newSession())
        let held = try quote("held")
        try await store.add(held, sessionID: session.id)

        try await store.saveDraft(sessionID: session.id, body: "typed")
        try await store.saveDraft(sessionID: session.id, body: "")

        #expect(try await store.replyQuotes(sessionID: session.id) == [held])
    }

    @Test func quotesStayInTheirOwnChat() async throws {
        let store = try makeTestStore("reply-quotes-chats")
        let one = try await store.upsert(AskConversation.newSession())
        let other = try await store.upsert(AskConversation.newSession())
        try await store.add(try quote("one"), sessionID: one.id)

        #expect(try await store.replyQuotes(sessionID: other.id).isEmpty)
    }

    @Test func deletingTheChatTakesItsQuotes() async throws {
        let store = try makeTestStore("reply-quotes-cascade")
        let session = try await store.upsert(AskConversation.newSession())
        try await store.add(try quote("held"), sessionID: session.id)

        try await store.deleteSession(id: session.id)

        #expect(try await store.replyQuotes(sessionID: session.id).isEmpty)
    }

    @Test func removingAQuoteLeavesTheOthers() async throws {
        let store = try makeTestStore("reply-quotes-remove")
        let session = try await store.upsert(AskConversation.newSession())
        let gone = try quote("gone")
        let kept = try quote("kept")
        try await store.add(gone, sessionID: session.id)
        try await store.add(kept, sessionID: session.id)

        try await store.removeReplyQuotes(ids: [gone.id])

        #expect(try await store.replyQuotes(sessionID: session.id) == [kept])
    }

    @Test func sendingClearsOnlyTheQuotesItCarried() async throws {
        let store = try makeTestStore("reply-quotes-sent")
        let session = try await store.upsert(AskConversation.newSession())
        let sent = try quote("sent")
        let late = try quote("arrived after the send began")
        try await store.add(sent, sessionID: session.id)
        try await store.add(late, sessionID: session.id)

        _ = try await store.enqueueDelivery(
            Delivery(targetSessionID: session.id, body: sent.quoted),
            clearingDraftMatching: nil,
            clearingQuotes: [sent.id]
        )

        #expect(try await store.replyQuotes(sessionID: session.id) == [late])
    }

    @Test func aFailedEnqueueKeepsTheQuotes() async throws {
        let store = try makeTestStore("reply-quotes-failed-send")
        let session = try await store.upsert(AskConversation.newSession())
        let held = try quote("held")
        try await store.add(held, sessionID: session.id)
        let delivery = Delivery(targetSessionID: session.id, body: held.quoted)
        let direct = try SQLiteDatabase(path: store.path)
        try direct.execute("""
            CREATE TRIGGER refuse_deliveries BEFORE INSERT ON deliveries
            BEGIN SELECT RAISE(ABORT, 'refused'); END;
            """)

        await #expect(throws: (any Error).self) {
            try await store.enqueueDelivery(
                delivery, clearingDraftMatching: nil, clearingQuotes: [held.id]
            )
        }

        #expect(try await store.replyQuotes(sessionID: session.id) == [held])
    }
}
