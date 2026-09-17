import Testing
import Foundation
@testable import Core

@Suite("The setup run confirmation")
struct SetupRunConfirmationTests {
    @Test("the confirm button says what it will do rather than OK")
    func theConfirmButtonNamesTheAction() {
        let again = SetupRunConfirmation.question(hasRunSetup: true, isAgentRunning: false)
        #expect(again.confirmLabel == "Run Setup Again")

        let first = SetupRunConfirmation.question(hasRunSetup: false, isAgentRunning: false)
        #expect(first.confirmLabel == "Run Setup")
    }

    @Test("the title says again exactly when the item does")
    func theTitleFollowsTheItem() {
        #expect(
            SetupRunConfirmation.question(hasRunSetup: true, isAgentRunning: false).title
                == "Run setup again?"
        )
        #expect(
            SetupRunConfirmation.question(hasRunSetup: false, isAgentRunning: false).title
                == "Run setup?"
        )
    }

    @Test("the message always says what the run costs")
    func theMessageAlwaysSaysTheCost() {
        for hasRunSetup in [true, false] {
            for isAgentRunning in [true, false] {
                let question = SetupRunConfirmation.question(
                    hasRunSetup: hasRunSetup, isAgentRunning: isAgentRunning
                )
                #expect(question.message.contains("runs in the worktree"))
                #expect(question.message.contains("can take minutes"))
                #expect(question.message.contains("cannot undo"))
            }
        }
    }

    @Test("an idle workspace is told nothing about an agent")
    func anIdleWorkspaceSaysNothingAboutAnAgent() {
        let question = SetupRunConfirmation.question(hasRunSetup: true, isAgentRunning: false)
        #expect(!question.message.contains("agent"))
    }

    @Test("a workspace with an agent mid turn is told the script does not stop it")
    func aRunningAgentGetsTheCollisionLine() {
        let question = SetupRunConfirmation.question(hasRunSetup: true, isAgentRunning: true)
        #expect(question.message.contains("An agent is mid turn here"))
        #expect(question.message.contains("does not stop it"))
    }

    @Test("an agent mid turn adds a line and moves nothing else")
    func theAgentOnlyAddsALine() {
        let idle = SetupRunConfirmation.question(hasRunSetup: true, isAgentRunning: false)
        let busy = SetupRunConfirmation.question(hasRunSetup: true, isAgentRunning: true)

        #expect(busy.title == idle.title)
        #expect(busy.confirmLabel == idle.confirmLabel)
        #expect(busy.cancelLabel == idle.cancelLabel)
        #expect(busy.message.hasPrefix(idle.message))
    }

    @Test("the cancel button promises nothing happens")
    func theCancelButtonIsPlain() {
        #expect(
            SetupRunConfirmation.question(hasRunSetup: true, isAgentRunning: true).cancelLabel
                == "Don\u{2019}t Run"
        )
    }
}
