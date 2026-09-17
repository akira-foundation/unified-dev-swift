import Foundation
import Testing
@testable import Core

@Suite("The sending slot")
struct SendingSlotTests {
    private static let chat = SessionID("chat")

    private static func ownerTurn() -> Delivery {
        Delivery(targetSessionID: chat, body: "Fix the flaky test.")
    }

    private static func relayed() -> Delivery {
        let message = WorkspaceMessage(
            source: WorkspaceMessageEnd(
                workspaceID: WorkspaceID("fixer"), workspace: "fix-the-bug", project: "apex", chat: "Chat"
            ),
            target: WorkspaceMessageEnd(workspaceID: WorkspaceID("releaser"), workspace: "release"),
            text: "Release a patch."
        )
        return Delivery(
            targetSessionID: chat, sourceWorkspaceID: WorkspaceID("fixer"), kind: .message,
            crew: message.crewMessage
        )
    }

    private static func report() -> Delivery {
        Delivery(
            targetSessionID: chat, kind: .report,
            crew: CrewMessage.said(from: "reader", text: "Done.", sender: .subagent)
        )
    }

    @Test("the owner's own row retires the owner's own sentence")
    func userRowRetiresOwnerTurn() {
        #expect(SendingSlot.retires(Self.ownerTurn(), onPersisting: .user))
    }

    @Test("a crew row retires a relayed message and a report, which the drain records as crew")
    func crewRowRetiresCrewSends() {
        #expect(SendingSlot.retires(Self.relayed(), onPersisting: .crew))
        #expect(SendingSlot.retires(Self.report(), onPersisting: .crew))
    }

    @Test("the owner's own row retires a relayed message too, as it always did")
    func userRowRetiresCrewSends() {
        #expect(SendingSlot.retires(Self.relayed(), onPersisting: .user))
        #expect(SendingSlot.retires(Self.report(), onPersisting: .user))
    }

    @Test("a crew row written while the owner's sentence is going does not take it off the screen")
    func crewRowLeavesOwnerTurn() {
        #expect(!SendingSlot.retires(Self.ownerTurn(), onPersisting: .crew))
    }

    @Test(
        "no other row retires anything, and nothing retires an empty slot",
        arguments: MessageKind.allCases
    )
    func otherKinds(kind: MessageKind) {
        #expect(!SendingSlot.retires(nil, onPersisting: kind))
        guard kind != .user, kind != .crew else { return }
        #expect(!SendingSlot.retires(Self.ownerTurn(), onPersisting: kind))
        #expect(!SendingSlot.retires(Self.relayed(), onPersisting: kind))
    }

    @Test("a relayed message is drawn as itself, never as the owner's bubble")
    func relayedDrawsAsItself() throws {
        guard case .workspaceMessage(let crew) = SendingSlot.drawing(of: Self.relayed()) else {
            Issue.record("expected a workspace message"); return
        }
        #expect(crew.text == "Release a patch.")
        #expect(crew.route?.workspace == "fix-the-bug")
    }

    @Test("a report is drawn as a crew message, and the owner's turn as the owner's bubble")
    func otherDrawings() {
        guard case .crewMessage(let crew) = SendingSlot.drawing(of: Self.report()) else {
            Issue.record("expected a crew message"); return
        }
        #expect(crew.event == .said)
        #expect(SendingSlot.drawing(of: Self.ownerTurn()) == .ownerTurn)
    }
}
