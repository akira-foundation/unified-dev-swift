import Foundation
import Testing
@testable import Core

@Suite("Tab strip fade")
struct TabStripFadeTests {
    @Test("tabs that fit the strip are drawn whole")
    func fittingTabsAreOpaque() {
        #expect(!TabStripFade.isDrawn(tabsWidth: 300, stripWidth: 600))
        #expect(!TabStripFade.isDrawn(tabsWidth: 600, stripWidth: 600))
    }

    @Test("a point of rounding between the two widths is not an overflow")
    func roundingIsNotOverflow() {
        #expect(!TabStripFade.isDrawn(tabsWidth: 601, stripWidth: 600))
    }

    @Test("tabs wider than the strip fade at the ends")
    func overflowingTabsFade() {
        #expect(TabStripFade.isDrawn(tabsWidth: 602, stripWidth: 600))
        #expect(TabStripFade.isDrawn(tabsWidth: 4_000, stripWidth: 600))
    }

    @Test("a strip that has not measured its tabs yet keeps the fade")
    func unmeasuredStripFades() {
        #expect(TabStripFade.isDrawn(tabsWidth: nil, stripWidth: 600))
        #expect(TabStripFade.isDrawn(tabsWidth: nil, stripWidth: 0))
    }

    @Test("the fade never takes more than half of the strip")
    func stepIsBounded() {
        #expect(TabStripFade.step(stripWidth: 0) == 0)
        #expect(TabStripFade.step(stripWidth: 20) == 0.5)
        #expect(TabStripFade.step(stripWidth: 160) == 0.1)
    }
}
