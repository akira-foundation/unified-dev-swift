import Foundation
import Testing
@testable import Core

@Suite("PaneSplit")
struct PaneSplitTests {
    private let chat = PaneContent.chat(SessionID(rawValue: "s-one"))
    private let tool = PaneContent.tool("t-one")

    @Test("a conversation splits into the same conversation")
    func chatSplits() {
        #expect(PaneSplit.duplicating(chat, tabKind: nil) == .sameContent)
        #expect(PaneSplit.duplicating(chat, tabKind: nil).opensAPane)
    }

    @Test("a shell and a page are one live view each, so the split gets a fresh one")
    func toolsGetAFreshOne() {
        #expect(PaneSplit.duplicating(tool, tabKind: .terminal) == .freshTerminal)
        #expect(PaneSplit.duplicating(tool, tabKind: .browser) == .freshBrowser)
    }

    @Test("the review and the notes cannot be split, so the menu has to grey rather than lie")
    func theOnesWithNoSecondCopy() {
        #expect(PaneSplit.duplicating(tool, tabKind: .review) == .nothing)
        #expect(PaneSplit.duplicating(tool, tabKind: .notes) == .nothing)
        #expect(!PaneSplit.duplicating(tool, tabKind: .review).opensAPane)
        #expect(!PaneSplit.duplicating(tool, tabKind: .notes).opensAPane)
    }

    @Test("a pointer at a tab that has been closed opens nothing either")
    func missingTab() {
        #expect(PaneSplit.duplicating(tool, tabKind: nil) == .nothing)
    }

    @Test("every kind is decided, so a new one cannot arrive enabled by default")
    func everyKindIsAnswered() {
        let splittable = CenterTabKind.allCases.filter {
            PaneSplit.duplicating(tool, tabKind: $0).opensAPane
        }
        #expect(Set(splittable) == [.terminal, .browser])
    }

    @Test("the stored spellings survived the move into the core")
    func wireFormat() {
        #expect(CenterTabKind.allCases.map(\.rawValue) == ["terminal", "browser", "review", "notes"])
    }

    @Test("the same again row is the kind a duplicate would have produced")
    func theRowThatCarriesTheKey() {
        #expect(PaneSplit.duplicating(chat, tabKind: nil).sameAgainKind == .chat)
        #expect(PaneSplit.duplicating(tool, tabKind: .terminal).sameAgainKind == .terminal)
        #expect(PaneSplit.duplicating(tool, tabKind: .browser).sameAgainKind == .browser)
    }

    @Test("a pane that cannot be split has no row for the key")
    func noRowWhenNothingOpens() {
        for kind in [CenterTabKind.review, .notes] {
            let outcome = PaneSplit.duplicating(tool, tabKind: kind)
            #expect(outcome.sameAgainKind == nil, "\(kind)")
            #expect(!outcome.opensAPane, "\(kind)")
        }
        #expect(PaneSplit.duplicating(tool, tabKind: nil).sameAgainKind == nil)
    }

    @Test("an outcome opens a pane exactly when it has a row to put the key on")
    func theTwoAnswersAgree() {
        let outcomes: [PaneDuplicateOutcome] = [.sameContent, .freshTerminal, .freshBrowser, .nothing]
        for outcome in outcomes {
            #expect(outcome.opensAPane == (outcome.sameAgainKind != nil), "\(outcome)")
        }
    }
}
