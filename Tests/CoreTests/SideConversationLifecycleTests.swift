import Foundation
import Testing
@testable import Core

@Suite("Side conversation lifecycle")
struct SideConversationLifecycleTests {
    private func opened(_ id: SessionID, quoting: String = "") -> SideConversationLifecycle {
        var life = SideConversationLifecycle()
        guard case .open(let opening) = life.start(quoting: quoting) else {
            Issue.record("an idle conversation must open")
            return life
        }
        _ = life.opened(id, generation: opening.generation)
        return life
    }

    @Test func aStartAfterACloseOpensAFreshConversationWithOnlyTheNewQuote() {
        let first = SessionID.new()
        var life = opened(first, quoting: "old quote")
        let ending = life.close()
        let start = life.start(quoting: "new quote")
        guard case .open(let opening) = start else {
            Issue.record("expected a fresh opening, got \(start)")
            return
        }
        let arrival = life.opened(SessionID.new(), generation: opening.generation)
        #expect(ending == first)
        #expect(opening.keeping == nil)
        #expect(arrival == SideConversationLifecycle.Arrival(quotes: ["new quote"], question: ""))
        #expect(life.sessionID != first)
    }

    @Test func aReplyIntoAnOpenConversationQuotesIntoIt() {
        let id = SessionID.new()
        var life = opened(id)
        life.hide()
        let start = life.start(quoting: "more")
        #expect(start == .resume(id, .init(quotes: ["more"], question: "")))
        #expect(life.isShown)
    }

    @Test func closingWhileOpeningDiscardsTheConversationThatArrivesLate() {
        var life = SideConversationLifecycle()
        guard case .open(let opening) = life.start(question: "Why?", quoting: "q") else {
            Issue.record("an idle conversation must open")
            return
        }
        #expect(life.close() == nil)
        let late = life.opened(SessionID.new(), generation: opening.generation)
        #expect(late == nil)
        #expect(life.phase == .idle)
        #expect(life.pendingQuotes.isEmpty)
        #expect(life.pendingQuestion.isEmpty)
    }

    @Test func aStaleOpeningCannotReplaceTheCurrentOne() {
        var life = SideConversationLifecycle()
        guard case .open(let stale) = life.start() else { return }
        _ = life.close()
        guard case .open(let current) = life.start(quoting: "new") else {
            Issue.record("a closed conversation must open again")
            return
        }
        #expect(life.opened(SessionID.new(), generation: stale.generation) == nil)
        #expect(life.opened(SessionID.new(), generation: current.generation)?.quotes == ["new"])
    }

    @Test func quotesAndQuestionsWhileOpeningArriveWithTheConversation() {
        var life = SideConversationLifecycle()
        guard case .open(let opening) = life.start(quoting: "a") else { return }
        #expect(life.start(question: "Why?", quoting: "b") == .wait)
        let arrival = life.opened(SessionID.new(), generation: opening.generation)
        #expect(arrival == .init(quotes: ["a", "b"], question: "Why?"))
    }

    @Test func keepEndsTheSideConversationSoTheNextStartIsFresh() {
        let kept = SessionID.new()
        var life = opened(kept, quoting: "x")
        #expect(life.keep() == kept)
        #expect(!life.isShown)
        guard case .open(let opening) = life.start() else {
            Issue.record("a kept conversation must not be resumed")
            return
        }
        #expect(opening.keeping == nil)
    }

    @Test func keepIsRefusedUntilTheConversationIsOpen() {
        var life = SideConversationLifecycle()
        _ = life.start(quoting: "x")
        #expect(life.keep() == nil)
        #expect(life.isOpening)
        #expect(life.pendingQuotes == ["x"])
    }

    @Test func startingNewKeepsTheOpenOne() {
        let id = SessionID.new()
        var life = opened(id)
        guard case .open(let opening) = life.start(fresh: true) else {
            Issue.record("fresh must open")
            return
        }
        #expect(opening.keeping == id)
    }

    @Test func aFailedOpeningLeavesNothingBehind() {
        var life = SideConversationLifecycle()
        guard case .open(let opening) = life.start(question: "Why?", quoting: "q") else { return }
        life.failed(generation: opening.generation)
        #expect(life.phase == .idle)
        #expect(life.pendingQuotes.isEmpty)
        #expect(life.pendingQuestion.isEmpty)
        #expect(life.isShown)
    }
}
