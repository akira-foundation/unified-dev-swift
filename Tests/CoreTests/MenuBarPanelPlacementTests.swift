import Foundation
import Testing
@testable import Core

@Suite("Menu bar panel placement")
struct MenuBarPanelPlacementTests {
    private let laptop = CGRect(x: 0, y: 0, width: 1440, height: 875)

    @Test("hangs centred under the icon, just below the menu bar")
    func centred() {
        let placement = MenuBarPanelPlacement.place(
            anchor: CGRect(x: 700, y: 876, width: 40, height: 24), visible: laptop, contentHeight: 400
        )
        #expect(placement.frame == CGRect(x: 540, y: 469, width: 360, height: 400))
        #expect(!placement.scrolls)
    }

    @Test("stays on the screen when the icon sits near its right edge")
    func clampsRight() {
        let placement = MenuBarPanelPlacement.place(
            anchor: CGRect(x: 1400, y: 876, width: 30, height: 24), visible: laptop, contentHeight: 300
        )
        #expect(placement.frame.maxX == 1432)
    }

    @Test("stops at the height of the screen and scrolls inside")
    func tall() {
        let placement = MenuBarPanelPlacement.place(
            anchor: CGRect(x: 700, y: 876, width: 40, height: 24), visible: laptop, contentHeight: 2000
        )
        #expect(placement.frame.minY == 8)
        #expect(placement.frame.maxY == 869)
        #expect(placement.scrolls)
    }

    @Test("opens on the display whose menu bar was used")
    func secondDisplay() {
        let external = CGRect(x: 1440, y: -200, width: 1920, height: 1055)
        let placement = MenuBarPanelPlacement.place(
            anchor: CGRect(x: 3000, y: 856, width: 30, height: 24), visible: external, contentHeight: 500
        )
        #expect(placement.frame.minX == 2835)
        #expect(placement.frame.maxY == 849)
        #expect(external.contains(placement.frame))
    }

    @Test("stays on the screen when the icon sits near its left edge")
    func clampsLeft() {
        let placement = MenuBarPanelPlacement.place(
            anchor: CGRect(x: 10, y: 876, width: 30, height: 24), visible: laptop, contentHeight: 300
        )
        #expect(placement.frame.minX == 8)
    }

    @Test("hangs from the icon when the menu bar sits lower than the visible frame")
    func hiddenMenuBar() {
        let full = CGRect(x: 0, y: 0, width: 1440, height: 900)
        let placement = MenuBarPanelPlacement.place(
            anchor: CGRect(x: 700, y: 876, width: 40, height: 24), visible: full, contentHeight: 300
        )
        #expect(placement.frame.maxY == 870)
    }

    @Test("a screen narrower than the panel keeps it at the left margin")
    func narrow() {
        let placement = MenuBarPanelPlacement.place(
            anchor: CGRect(x: 200, y: 876, width: 30, height: 24),
            visible: CGRect(x: 0, y: 0, width: 300, height: 875),
            contentHeight: 300
        )
        #expect(placement.frame.minX == 8)
    }
}
