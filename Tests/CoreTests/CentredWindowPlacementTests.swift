import CoreGraphics
import Testing
@testable import Core

@Suite("CentredWindowPlacement")
struct CentredWindowPlacementTests {
    @Test("Centres on an offset owner rather than the display")
    func owner() {
        let owner = CGRect(x: 400, y: 120, width: 1000, height: 800)
        let frame = CentredWindowPlacement.frame(size: CGSize(width: 520, height: 424), around: owner,
                                                visible: CGRect(x: 0, y: 0, width: 2000, height: 1200))
        #expect(frame.midX == owner.midX)
        #expect(frame.midY == owner.midY)
    }

    @Test("Changing steps keeps the top edge still when growing and shrinking",
          arguments: [300.0, 424.0, 534.0, 747.0] as [CGFloat])
    func resize(height: CGFloat) {
        let before = CGRect(x: 400, y: 400, width: 520, height: 424)
        let frame = CentredWindowPlacement.frame(size: CGSize(width: 520, height: height), keepingTopOf: before,
                                                visible: CGRect(x: 0, y: 0, width: 2000, height: 1400))
        #expect(frame.maxY == before.maxY)
        #expect(frame.midX == before.midX)
        #expect(frame.height == height)
    }

    @Test("A step too tall for the space below is lifted rather than cut off")
    func resizeNearBottom() {
        let visible = CGRect(x: 0, y: 30, width: 1440, height: 870)
        let before = CGRect(x: 400, y: 60, width: 520, height: 424)
        let frame = CentredWindowPlacement.frame(size: CGSize(width: 520, height: 747), keepingTopOf: before,
                                                visible: visible)
        #expect(visible.contains(frame))
        #expect(frame.minY == visible.minY)
    }

    @Test("Keeps every edge on the owner's display", arguments: [-1800.0, 0.0, 1800.0])
    func screenEdges(origin: Double) {
        let visible = CGRect(x: origin, y: 30, width: 1440, height: 870)
        for anchor in [CGRect(x: origin - 100, y: -100, width: 200, height: 200),
                       CGRect(x: visible.maxX - 10, y: visible.maxY - 10, width: 200, height: 200)] {
            let frame = CentredWindowPlacement.frame(size: CGSize(width: 520, height: 424), around: anchor, visible: visible)
            #expect(visible.contains(frame))
        }
    }

    @Test func shrinksAWindowThatIsWiderThanTheRoomItHas() {
        let wanted = CGSize(width: 1600, height: 1000)
        #expect(
            CentredWindowPlacement.fitted(wanted, within: CGSize(width: 1470, height: 956))
                == CGSize(width: 1470, height: 956)
        )
        #expect(
            CentredWindowPlacement.fitted(wanted, within: CGSize(width: 1728, height: 1039))
                == CGSize(width: 1600, height: 1000)
        )
    }

    @Test func shrinksOnlyTheAxisThatOverflows() {
        #expect(
            CentredWindowPlacement.fitted(
                CGSize(width: 1600, height: 1000), within: CGSize(width: 1728, height: 900)
            ) == CGSize(width: 1600, height: 900)
        )
        #expect(
            CentredWindowPlacement.fitted(
                CGSize(width: 1600, height: 1000), within: CGSize(width: 1400, height: 1200)
            ) == CGSize(width: 1400, height: 1000)
        )
    }

    @Test func leavesTheWantedSizeAloneWhenItKnowsOfNoRoom() {
        let wanted = CGSize(width: 1600, height: 1000)
        #expect(CentredWindowPlacement.fitted(wanted, within: .zero) == wanted)
    }
}
