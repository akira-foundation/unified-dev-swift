import Foundation
import Testing
@testable import Core

@Suite("Search panel actions")
struct SearchPanelActionsTests {
    @Test("a live workspace is offered its whole row menu, in the row menu's order")
    func aLiveWorkspace() {
        let rows = SearchPanelActions.rows(for: .live(WorkspaceID("w1")))
        #expect(rows.map(\.item.action) == [
            .openInEditor, .revealInFinder, .copyName, .copyBranchName,
            .pin, .unreadMark, .renameWorkspace, .archive,
        ])
    }

    @Test("an archived workspace is offered what Home offers it and nothing more")
    func anArchivedWorkspace() {
        let rows = SearchPanelActions.rows(for: .archived(WorkspaceID("w1")))
        #expect(rows.map(\.item.action) == [.copyName, .copyBranchName, .restore])
    }

    @Test("the action list is one section with no heading")
    func oneSectionNoHeading() {
        let sections = SearchPanelActions.sections(for: .live(WorkspaceID("w1")))
        #expect(sections.count == 1)
        #expect(sections[0].title == nil)
    }

    @Test("every workspace menu action names a row in the catalogue, and the map goes both ways")
    func theMapIsComplete() {
        for action in WorkspaceMenuAction.allCases {
            let menuBar = SearchPanelActions.menuBarAction(for: action)
            #expect(MenuBarCatalogue[menuBar].menu == .workspace)
            #expect(SearchPanelActions.workspaceAction(for: menuBar) == action)
        }
    }

    @Test("the colour submenu is not offered as a row")
    func colourIsNotARow() {
        let offered = SearchPanelActions.rows(for: .live(WorkspaceID("w1"))).map(\.item.action)
        #expect(!offered.contains(.colour))
        #expect(!SearchPanelActions.order.contains(.colour))
    }
}
