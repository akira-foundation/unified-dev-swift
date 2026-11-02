import Testing
import Foundation
@testable import Core

@Suite struct BackgroundTasksFocusTests {
    private let chatA = SessionID("a")
    private let chatB = SessionID("b")
    private let chatC = SessionID("c")

    @Test func withNoChoiceTheTasksAreTheActiveChats() {
        #expect(BackgroundTasksFocus().session(active: chatA) == chatA)
        #expect(BackgroundTasksFocus().session(active: nil) == nil)
    }

    @Test func aPillPressedInAnotherPaneShowsThatPanesChat() {
        var focus = BackgroundTasksFocus()
        focus.choose(chatB, active: chatA)
        #expect(focus.session(active: chatA) == chatB)
    }

    @Test func goingToAnotherChatAndBackForgetsThePill() {
        var focus = BackgroundTasksFocus()
        focus.choose(chatB, active: chatA)
        focus.activeChatChanged()
        #expect(focus.session(active: chatC) == chatC)
        focus.activeChatChanged()
        #expect(focus.session(active: chatA) == chatA)
    }

    @Test func aChoiceMadeUnderOneActiveChatDoesNotApplyUnderAnother() {
        var focus = BackgroundTasksFocus()
        focus.choose(chatB, active: chatA)
        #expect(focus.session(active: chatC) == chatC)
    }
}
