import Foundation
import Testing
@testable import Core

@Suite("Search panel field")
struct SearchPanelFieldTests {
    @Test("a leading > switches to commands and is taken off the query")
    func theePrefixIsConsumed() {
        var field = SearchPanelField()
        field.type(">")
        #expect(field.mode == .commands)
        #expect(field.text.isEmpty)

        field.type("merge")
        #expect(field.mode == .commands)
        #expect(field.query == "merge")
    }

    @Test("one space after the prefix goes with the prefix")
    func oneSpaceIsEaten() {
        var typed = SearchPanelField()
        typed.type("> merge")
        #expect(typed.query == "merge")

        var tight = SearchPanelField()
        tight.type(">merge")
        #expect(tight.query == "merge")

        var padded = SearchPanelField()
        padded.type(">  merge")
        #expect(padded.query == " merge")
    }

    @Test("a > that is not the first character is a character like any other")
    func onlyTheFirstCharacterCounts() {
        var field = SearchPanelField()
        field.type("feature>thing")
        #expect(field.mode == .things)
        #expect(field.query == "feature>thing")
    }

    @Test("a > typed inside commands is a character, not a second mode")
    func theePrefixIsReadOnceOnly() {
        var field = SearchPanelField()
        field.type(">")
        field.type(">merge")
        #expect(field.mode == .commands)
        #expect(field.query == ">merge")
    }

    @Test("backspace on an empty field leaves commands, and does nothing at rest")
    func backspaceLeavesTheMode() {
        var field = SearchPanelField()
        let atRest = field.leaveMode()
        #expect(atRest == false)

        field.type(">")
        let left = field.leaveMode()
        #expect(left)
        #expect(field.mode == .things)
    }

    @Test("leaving an action list puts the earlier query back")
    func leavingRestoresTheQuery() {
        var field = SearchPanelField()
        field.type("docs")
        let entered = field.enterActions(on: WorkspaceID("w1"))
        #expect(entered)
        #expect(field.mode == .actions(WorkspaceID("w1")))
        #expect(field.text.isEmpty)

        let left = field.leaveMode()
        #expect(left)
        #expect(field.mode == .things)
        #expect(field.query == "docs")
    }

    @Test("only a search of things can be pushed into")
    func actionsAreEnteredFromThingsAlone() {
        var field = SearchPanelField()
        field.type(">")
        let entered = field.enterActions(on: WorkspaceID("w1"))
        #expect(entered == false)
        #expect(field.mode == .commands)
    }

    @Test("clearing empties the text and keeps the mode")
    func clearingKeepsTheMode() {
        var field = SearchPanelField()
        field.type(">")
        field.type("merge")
        field.clear()
        #expect(field.mode == .commands)
        #expect(field.isEmpty)
    }

    @Test("the scope chips are drawn while searching things and never in a mode")
    func onlyThingsHaveScopes() {
        #expect(SearchPanelMode.things.showsScopes)
        #expect(!SearchPanelMode.commands.showsScopes)
        #expect(!SearchPanelMode.actions(WorkspaceID("w1")).showsScopes)
        #expect(SearchPanelMode.things.pill == nil)
        #expect(SearchPanelMode.commands.pill == "Commands")
    }
}
