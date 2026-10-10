import Foundation
import Testing
@testable import Core

@Suite("Which question draft is let go of")
struct AgentQuestionDraftLedgerTests {
    @Test("nothing is let go of while there is room")
    func underTheLimit() {
        var ledger = AgentQuestionDraftLedger(limit: 3)
        for key in ["a", "b", "c"] { ledger.used(key) }

        #expect(ledger.dropping(where: { _ in true }).isEmpty)
        #expect(ledger.order == ["a", "b", "c"])
    }

    @Test("the one touched longest ago goes first, not the one opened first")
    func leastRecentlyUsed() {
        var ledger = AgentQuestionDraftLedger(limit: 2)
        for key in ["a", "b", "a", "c"] { ledger.used(key) }

        #expect(ledger.dropping(where: { _ in true }) == ["b"])
        #expect(ledger.order == ["a", "c"])
    }

    @Test("a draft the owner has written in is never let go of, however old it is")
    func writtenDraftsSurvive() {
        var ledger = AgentQuestionDraftLedger(limit: 1)
        for key in ["written", "b", "c"] { ledger.used(key) }

        let dropped = ledger.dropping(where: { $0 != "written" })

        #expect(dropped == ["b", "c"])
        #expect(ledger.order == ["written"])
    }

    @Test("a card reopened in the history cannot push out the question being answered")
    func reopeningDoesNotCostTheLiveDraft() {
        var ledger = AgentQuestionDraftLedger(limit: 2)
        ledger.used("live")

        for card in 0..<64 {
            ledger.used("history-\(card)")
            _ = ledger.dropping(where: { $0 != "live" })
        }

        #expect(ledger.order.contains("live"))
        #expect(ledger.order.count == 2)
    }
}
