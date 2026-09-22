import Foundation
import Testing
@testable import Core

@Suite("Crew messages")
struct CrewMessageTests {
    @Test("what a person reads and what the model reads are both kept")
    func bothRenderings() {
        let message = CrewMessage.said(from: "reader", text: "2 + 2 = 4.", sender: .subagent)

        #expect(message.text == "2 + 2 = 4.")
        #expect(message.sent.contains(BridgeUntrustedText.opening))
        #expect(message.sent.contains("2 + 2 = 4."))
        #expect(!message.text.contains(BridgeUntrustedText.opening))
    }

    @Test("who is speaking decides which way the envelope is worded")
    func envelopeNamesTheSpeaker() {
        let up = CrewMessage.said(from: "reader", text: "Done.", sender: .subagent)
        let down = CrewMessage.said(from: "Chat", text: "Carry on.", sender: .orchestrator)

        #expect(up.sent.contains("your subagent \"reader\""))
        #expect(down.sent.contains("the agent that started you, \"Chat\""))
    }

    @Test("a brief is not wrapped, because it is this agent's task")
    func briefIsNotWrapped() {
        let brief = CrewMessage.brief(from: "Chat", task: "Read the cascade and report.")

        #expect(brief.sent == brief.text)
        #expect(brief.sender == .orchestrator)
        #expect(!brief.sent.contains(BridgeUntrustedText.opening))
    }

    @Test("a stop says one line on screen and a paragraph to the model")
    func stopsAreSaidTwice() {
        let stop = CrewMessage.stopped(name: "reader", lastMessage: "All 18 tests pass.")

        #expect(stop.text == "reader stopped")
        #expect(stop.sender == .unifieddev)
        #expect(stop.sent.contains("All 18 tests pass."))
        #expect(stop.sent.contains("agent_stop"))
    }

    @Test("a failure keeps its reason on screen, because that is the whole of the news")
    func failuresKeepTheirReason() {
        let failure = CrewMessage.failed(name: "tests", reason: "The process exited.")

        #expect(failure.text.contains("tests"))
        #expect(failure.text.contains("The process exited."))
        #expect(failure.sender == .unifieddev)
    }

    @Test("a silent stop says so rather than showing an empty quotation")
    func silentStop() {
        let stop = CrewMessage.stopped(name: "reader", lastMessage: "   ")

        #expect(stop.sent.contains("said nothing"))
        #expect(stop.text == "reader stopped")
    }

    @Test("every stop tells the orchestrator how to finish with the agent")
    func theHintIsAlwaysThere() {
        let spoken = CrewMessage.stopped(name: "reader", lastMessage: "Done.")
        let silent = CrewMessage.stopped(name: "reader", lastMessage: nil)

        #expect(spoken.sent.contains(Crew.tidyHint))
        #expect(silent.sent.contains(Crew.tidyHint))
        #expect(Crew.tidyHint.contains("agent_stop"))
    }

    @Test("a row survives being written and read back")
    func roundTrip() throws {
        let message = CrewMessage.said(from: "reader", text: "Done.", sender: .subagent)
        let payload = try message.payload()

        #expect(CrewMessage.decode(payload) == message)
    }

    @Test("a workspace done notice survives the round trip and is a fact, not something said")
    func workspaceDoneRoundTrip() throws {
        let message = CrewMessage(
            event: .workspaceDone, sender: .unifieddev, from: "release",
            text: "release finished", sent: "The agent in the workspace \"release\" has finished."
        )

        let decoded = try #require(CrewMessage.decode(try message.payload()))

        #expect(decoded == message)
        #expect(decoded.event == .workspaceDone)
        #expect(CrewMessage.Event(rawValue: "workspace_done") == .workspaceDone)
    }

    @Test("anything that is not one of ours decodes to nil")
    func foreignPayloads() {
        #expect(CrewMessage.decode(Data("{\"type\":\"assistant\"}".utf8)) == nil)
        #expect(CrewMessage.decode(Data("not json at all".utf8)) == nil)
        #expect(CrewMessage.decode(Data()) == nil)
    }
}
