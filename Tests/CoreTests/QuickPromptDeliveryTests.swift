import Testing
import Foundation
@testable import Core

@Suite("Quick prompt delivery")
struct QuickPromptDeliveryTests {
    private static func prompt(sends: Bool = false, newChat: Bool = false) -> QuickPrompt {
        QuickPrompt(
            name: "Ship it",
            text: "Push the branch.",
            sendsImmediately: sends,
            opensNewChat: newChat
        )
    }

    @Test("a prompt with nothing turned on writes into the box and stops")
    func offByDefault() {
        let plain = QuickPrompt(name: "Explain", text: "Explain the changes.")
        #expect(!plain.sendsImmediately)
        #expect(!plain.opensNewChat)
        #expect(QuickPromptDelivery(plain) == .compose)
        #expect(!QuickPromptDelivery(plain).sends)
        #expect(!QuickPromptDelivery(plain).opensNewChat)
    }

    @Test("the two switches are the four things a press can do")
    func theFour() {
        #expect(QuickPromptDelivery(Self.prompt()) == .compose)
        #expect(QuickPromptDelivery(Self.prompt(sends: true)) == .send)
        #expect(QuickPromptDelivery(Self.prompt(newChat: true)) == .composeInNewChat)
        #expect(QuickPromptDelivery(Self.prompt(sends: true, newChat: true)) == .sendInNewChat)
    }

    @Test("each case says whether it sends and whether it opens a chat")
    func readsBack() {
        for delivery in QuickPromptDelivery.allCases {
            let round = QuickPromptDelivery(
                sendsImmediately: delivery.sends, opensNewChat: delivery.opensNewChat
            )
            #expect(round == delivery)
        }
    }

    @Test("a surface that can do neither writes into the box, whatever the prompt asks")
    func composeOnlySurface() {
        for delivery in QuickPromptDelivery.allCases {
            let asked = Self.prompt(sends: delivery.sends, newChat: delivery.opensNewChat)
            let decided = QuickPromptDelivery.decided(
                for: asked, canSend: false, canOpenNewChat: false
            )
            #expect(decided == .compose)
        }
    }

    @Test("with no strip to open a chat on, a send in place still sends")
    func sendsInPlace() {
        let decided = QuickPromptDelivery.decided(
            for: Self.prompt(sends: true), canSend: true, canOpenNewChat: false
        )
        #expect(decided == .send)
    }

    @Test("a prompt that wanted a chat it cannot have waits in the box rather than sending here")
    func neverSendsSomewhereItWasNotAskedTo() {
        let both = QuickPromptDelivery.decided(
            for: Self.prompt(sends: true, newChat: true), canSend: true, canOpenNewChat: false
        )
        #expect(both == .compose)

        let quiet = QuickPromptDelivery.decided(
            for: Self.prompt(newChat: true), canSend: true, canOpenNewChat: false
        )
        #expect(quiet == .compose)
    }

    @Test("a conversation with a strip behind it does what the prompt asks")
    func fullSurface() {
        for delivery in QuickPromptDelivery.allCases {
            let asked = Self.prompt(sends: delivery.sends, newChat: delivery.opensNewChat)
            let decided = QuickPromptDelivery.decided(
                for: asked, canSend: true, canOpenNewChat: true
            )
            #expect(decided == delivery)
        }
    }

    @Test("every combination that does something has its own sentence")
    func sentences() {
        let said = QuickPromptDelivery.allCases.compactMap(\.sentence)
        #expect(said.count == QuickPromptDelivery.allCases.count - 1)
        #expect(Set(said).count == said.count)
        #expect(said.allSatisfy { !$0.isEmpty })
    }

    @Test("both switches off explains nothing, because nothing unusual happens")
    func quietCombinationSaysNothing() {
        #expect(QuickPromptDelivery.compose.sentence == nil)
    }

    @Test("the sentence for sending in place names what is already in the box")
    func namesTheDraft() {
        #expect(QuickPromptDelivery.send.sentence?.contains("already typed") == true)
    }

    @Test("both of the new chat sentences say a chat opens, and only one of them sends")
    func namesTheChat() {
        #expect(QuickPromptDelivery.composeInNewChat.sentence?.contains("new chat") == true)
        #expect(QuickPromptDelivery.sendInNewChat.sentence?.contains("new chat") == true)
        #expect(QuickPromptDelivery.composeInNewChat.sentence?.contains("Nothing is sent") == true)
    }

    @Test("a named prompt names the chat it opens, and an unnamed one leaves it to the strip")
    func chatTitle() {
        #expect(Self.prompt().chatTitle == "Ship it")
        #expect(QuickPrompt(name: "", text: "Walk me through the diff.").chatTitle == nil)
        #expect(QuickPrompt(name: "   ", text: "Walk me through the diff.").chatTitle == nil)
        #expect(QuickPrompt(name: "  Ship it  ", text: "Push.").chatTitle == "Ship it")
    }
}
