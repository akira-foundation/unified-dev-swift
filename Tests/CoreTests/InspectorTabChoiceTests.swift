import Foundation
import Testing
@testable import Core

@Suite("Inspector tab choice")
struct InspectorTabChoiceTests {
    private let withSide = InspectorTab.available(for: nil, hasSideConversation: true)
    private let withoutSide = InspectorTab.available(for: nil)

    @Test("starting a side conversation selects Side", arguments: [InspectorTab.allFiles, .changes, .tasks])
    func startSelectsSide(_ before: InspectorTab) {
        var choice = InspectorTabChoice(before)
        choice.sideConversationStarted()
        #expect(choice.resolved(available: withSide) == .side)
    }

    @Test("leaving the side conversation goes back to the tab it replaced")
    func leavingReturns() {
        var choice = InspectorTabChoice(.allFiles)
        choice.sideConversationStarted()
        choice.sideConversationLeft()
        #expect(choice.chosen == .allFiles)
    }

    @Test("a tab picked while Side was open stays picked when the side conversation ends")
    func pickedTabSurvives() {
        var choice = InspectorTabChoice(.allFiles)
        choice.sideConversationStarted()
        choice.choose(.changes)
        choice.sideConversationLeft()
        #expect(choice.chosen == .changes)
    }

    @Test("Changes and the rest stay one click away while Side is selected")
    func otherTabsStayOnOffer() {
        var choice = InspectorTabChoice()
        choice.sideConversationStarted()
        #expect(withSide.contains(.changes))
        choice.choose(.changes)
        #expect(choice.resolved(available: withSide) == .changes)
    }

    @Test("a second start while Side is selected keeps the tab it first replaced")
    func secondStartKeepsTheOrigin() {
        var choice = InspectorTabChoice(.allFiles)
        choice.sideConversationStarted()
        choice.sideConversationStarted()
        choice.sideConversationLeft()
        #expect(choice.chosen == .allFiles)
    }

    @Test("Side chosen with no side conversation on offer falls back to Changes")
    func sideWithoutConversationFallsBack() {
        var choice = InspectorTabChoice(.tasks)
        choice.sideConversationStarted()
        #expect(choice.resolved(available: withoutSide) == .changes)
    }

    @Test("ending while another tab is selected leaves it alone")
    func endingElsewhereIsANoOp() {
        var choice = InspectorTabChoice(.allFiles)
        choice.sideConversationLeft()
        #expect(choice.chosen == .allFiles)
    }
}
