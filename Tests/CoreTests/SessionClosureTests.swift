import Foundation
import Testing
@testable import Core

@Suite("SessionClosure")
struct SessionClosureTests {
    @Test("an idle conversation with others beside it closes on the first click")
    func nothingToLose() {
        let cost = SessionClosure.closing(isRunning: true == false, otherConversations: 2)

        #expect(cost.isEmpty)
        #expect(cost.needsConfirmation == false)
        #expect(cost.reasons.isEmpty)
    }

    @Test("a conversation in the middle of a turn is asked about")
    func midTurn() {
        let cost = SessionClosure.closing(isRunning: true, otherConversations: 2)

        #expect(cost == .stopsATurn)
        #expect(cost.needsConfirmation)
        #expect(cost.reasons.count == 1)
        #expect(cost.reasons[0].contains("cannot be resumed"))
    }

    @Test("the workspace's only conversation is asked about even when it is idle")
    func lastConversation() {
        let cost = SessionClosure.closing(isRunning: false, otherConversations: 0)

        #expect(cost == .leavesNoConversation)
        #expect(cost.needsConfirmation)
        #expect(cost.reasons.count == 1)
        #expect(cost.reasons[0].contains("does not come back"))
    }

    @Test("a working conversation that is also the last one says both things")
    func both() {
        let cost = SessionClosure.closing(isRunning: true, otherConversations: 0)

        #expect(cost.contains(.stopsATurn))
        #expect(cost.contains(.leavesNoConversation))
        #expect(cost.reasons.count == 2)
        #expect(cost.reasons[0].contains("cannot be resumed"))
        #expect(cost.reasons[1].contains("only conversation"))
    }

    @Test("a count that has already gone negative still reads as the last one")
    func negativeCount() {
        #expect(SessionClosure.closing(isRunning: false, otherConversations: -1) == .leavesNoConversation)
    }

    @Test("the question names the conversation it is about")
    func namedTitle() {
        #expect(SessionClosure.stopsATurn.title(of: "Fix the parser") == "Fix the parser is still working")
        #expect(
            SessionClosure.leavesNoConversation.title(of: "Fix the parser")
                == "Fix the parser is the only conversation here"
        )
    }

    @Test("a conversation with no name of its own is still asked about in a sentence")
    func unnamedTitle() {
        #expect(SessionClosure.stopsATurn.title(of: "") == "This conversation is still working")
        #expect(SessionClosure.stopsATurn.title(of: "   ") == "This conversation is still working")
        #expect(
            SessionClosure.leavesNoConversation.title(of: "")
                == "This conversation is the only conversation here"
        )
    }

    @Test("a turn in flight is what the question leads with when there are two costs")
    func titleLeadsWithTheTurn() {
        let both: SessionClosure = [.stopsATurn, .leavesNoConversation]

        #expect(both.title(of: "Fix the parser") == "Fix the parser is still working")
    }

    @Test("the buttons answer the question that was asked")
    func buttons() {
        #expect(SessionClosure.stopsATurn.confirmTitle == "Close anyway")
        #expect(SessionClosure.stopsATurn.cancelTitle == "Keep working")
        #expect(SessionClosure.leavesNoConversation.confirmTitle == "Close it")
        #expect(SessionClosure.leavesNoConversation.cancelTitle == "Keep it")
    }

    @Test("asking and having something to say are the same condition")
    func askingAlwaysExplains() {
        for raw in 0...3 {
            let cost = SessionClosure(rawValue: raw)
            #expect(cost.needsConfirmation == !cost.reasons.isEmpty)
        }
    }
}
