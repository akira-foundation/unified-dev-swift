import Testing
import CoreGraphics
@testable import Core

@Suite("ToolbarTabsWidth")
struct ToolbarTabsWidthTests {
    @Test("the tabs take the centre column less the room the toolbar actions need")
    func fillsTheColumn() {
        #expect(ToolbarTabsWidth.width(inColumn: 900) == 730)
    }

    @Test("the minimum takes over exactly where the column leaves no more room than it")
    func boundary() {
        #expect(ToolbarTabsWidth.width(inColumn: 410) == 240)
        #expect(ToolbarTabsWidth.width(inColumn: 411) == 241)
        #expect(ToolbarTabsWidth.width(inColumn: 409) == 240)
    }

    @Test("a narrow column keeps the tabs at their minimum rather than shrinking them away")
    func neverBelowMinimum() {
        #expect(ToolbarTabsWidth.width(inColumn: 300) == 240)
        #expect(ToolbarTabsWidth.width(inColumn: 0) == 240)
    }

    @Test("the strip shows only when there is more than one tab")
    func stripNeedsTwoTabs() {
        #expect(!ToolbarTabsWidth.showsStrip(tabCount: 0))
        #expect(!ToolbarTabsWidth.showsStrip(tabCount: 1))
        #expect(ToolbarTabsWidth.showsStrip(tabCount: 2))
    }
}
