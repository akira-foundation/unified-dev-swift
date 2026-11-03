import Testing
@testable import Core

@Suite("Selection actions")
struct SelectionActionsTests {
    @Test(arguments: [
        (MessageKind.user, true), (.assistantText, true), (.thinking, false),
        (.toolUse, false), (.toolResult, false), (.error, false), (.notice, false)
    ])
    func acceptsOnlyMessagesAndAnswers(kind: MessageKind, expected: Bool) {
        #expect(SelectionActions.accepts(kind) == expected)
    }

    @Test func branchingNeedsAnActiveWorkspaceChat() {
        #expect(SelectionActions.canBranch(isAsk: false, isSideConversation: false, workspaceIsActive: true))
        #expect(!SelectionActions.canBranch(isAsk: true, isSideConversation: false, workspaceIsActive: true))
        #expect(!SelectionActions.canBranch(isAsk: false, isSideConversation: true, workspaceIsActive: true))
        #expect(!SelectionActions.canBranch(isAsk: false, isSideConversation: false, workspaceIsActive: false))
    }
}
