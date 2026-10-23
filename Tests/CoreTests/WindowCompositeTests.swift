import Testing
import CoreGraphics
@testable import Core

@Suite("Window composite")
struct WindowCompositeTests {
    private let main = CGRect(x: 100, y: 200, width: 1600, height: 1000)

    private let screen = CGRect(x: 0, y: 0, width: 1728, height: 1117)

    @Test func drawsTheWindowAloneWhenNothingHangsOffIt() {
        let layout = WindowComposite.layout(parent: main, children: [], scale: 2)
        #expect(layout.size == CGSize(width: 3200, height: 2000))
        #expect(layout.parent == CGRect(x: 0, y: 0, width: 3200, height: 2000))
        #expect(layout.children.isEmpty)
    }

    @Test func turnsScreenCoordinatesIntoImageCoordinates() {
        let popover = CGRect(x: 400, y: 300, width: 300, height: 400)
        let layout = WindowComposite.layout(parent: main, children: [popover], scale: 1)
        #expect(layout.children == [CGRect(x: 300, y: 500, width: 300, height: 400)])
    }

    @Test func growsTheCanvasForAPopoverHangingBelowTheWindow() {
        let popover = CGRect(x: 300, y: 60, width: 320, height: 200)
        let layout = WindowComposite.layout(parent: main, children: [popover], scale: 1)
        #expect(layout.size == CGSize(width: 1600, height: 1140))
        #expect(layout.parent == CGRect(x: 0, y: 0, width: 1600, height: 1000))
        #expect(layout.children == [CGRect(x: 200, y: 940, width: 320, height: 200)])
    }

    @Test func growsTheCanvasToTheLeftOfTheWindowToo() {
        let popover = CGRect(x: 40, y: 400, width: 200, height: 100)
        let layout = WindowComposite.layout(parent: main, children: [popover], scale: 1)
        #expect(layout.size == CGSize(width: 1660, height: 1000))
        #expect(layout.parent == CGRect(x: 60, y: 0, width: 1600, height: 1000))
        #expect(layout.children == [CGRect(x: 0, y: 700, width: 200, height: 100)])
    }

    @Test func coversEveryChildItIsGiven() {
        let left = CGRect(x: 40, y: 400, width: 200, height: 100)
        let right = CGRect(x: 1650, y: 900, width: 300, height: 150)
        let layout = WindowComposite.layout(parent: main, children: [left, right], scale: 1)
        #expect(layout.bounds == CGRect(x: 40, y: 200, width: 1910, height: 1000))
        #expect(layout.children.count == 2)
        #expect(layout.children[0] == CGRect(x: 0, y: 700, width: 200, height: 100))
        #expect(layout.children[1] == CGRect(x: 1610, y: 150, width: 300, height: 150))
    }

    @Test func scalesEveryPlacementByTheBackingFactor() {
        let popover = CGRect(x: 400, y: 300, width: 300, height: 400)
        let layout = WindowComposite.layout(parent: main, children: [popover], scale: 2)
        #expect(layout.children == [CGRect(x: 600, y: 1000, width: 600, height: 800)])
    }

    @Test func leavesOutAWindowWithNothingInIt() {
        let empty = CGRect(x: -400, y: -400, width: 0, height: 0)
        let layout = WindowComposite.layout(parent: main, children: [empty], scale: 1)
        #expect(layout.children.isEmpty)
        #expect(layout.size == main.size)
    }

    @Test func treatsANonsenseScaleAsOne() {
        let popover = CGRect(x: 400, y: 300, width: 300, height: 400)
        let layout = WindowComposite.layout(parent: main, children: [popover], scale: 0)
        #expect(layout.size == main.size)
        #expect(layout.parent == CGRect(x: 0, y: 0, width: 1600, height: 1000))
        #expect(layout.children == [CGRect(x: 300, y: 500, width: 300, height: 400)])
    }

    @Test func clipsWhatItCoversToTheScreenItIsDrawnOn() {
        let popover = CGRect(x: 1600, y: 300, width: 320, height: 200)
        let layout = WindowComposite.layout(
            parent: main, children: [popover], scale: 1, within: screen
        )
        #expect(layout.bounds == CGRect(x: 100, y: 200, width: 1628, height: 917))
        #expect(layout.size == CGSize(width: 1628, height: 917))
        #expect(layout.parent == CGRect(x: 0, y: -83, width: 1600, height: 1000))
        #expect(layout.children == [CGRect(x: 1500, y: 617, width: 320, height: 200)])
    }

    @Test func coversTheWindowWholeWhenItIsNowhereNearTheScreen() {
        let parked = CGRect(x: -30_000, y: -30_000, width: 1600, height: 1000)
        let popover = CGRect(x: -29_800, y: -29_900, width: 320, height: 200)
        let layout = WindowComposite.layout(
            parent: parked, children: [popover], scale: 2, within: screen
        )
        #expect(layout.bounds == parked.union(popover))
        #expect(layout.size == CGSize(width: 3200, height: 2000))
        #expect(layout.parent == CGRect(x: 0, y: 0, width: 3200, height: 2000))
    }

    @Test func turnsItsBoundsOverIntoTheSpaceOfTheScreenItWasShotOn() {
        let layout = WindowComposite.layout(parent: main, children: [], scale: 1)
        #expect(layout.flipped(in: screen) == CGRect(x: 100, y: -83, width: 1600, height: 1000))
    }

    @Test func countsFromTheCornerOfAScreenThatIsNotThePrimaryOne() {
        let second = CGRect(x: 1728, y: 0, width: 1920, height: 1080)
        let onIt = CGRect(x: 1800, y: 40, width: 1600, height: 1000)
        let layout = WindowComposite.layout(parent: onIt, children: [], scale: 1, within: second)
        #expect(layout.flipped(in: second) == CGRect(x: 72, y: 40, width: 1600, height: 1000))
    }

    @Test func coversTheWindowWholeWhenItKnowsOfNoRoomToClipTo() {
        let layout = WindowComposite.layout(
            parent: main, children: [], scale: 1, within: .zero
        )
        #expect(layout.bounds == main)
        #expect(layout.size == main.size)
    }

    @Test func clipsAndThenCountsFromTheCornerOfTheSameScreen() {
        let below = CGRect(x: 0, y: -1080, width: 1920, height: 1080)
        let onIt = CGRect(x: 100, y: -1050, width: 1600, height: 1000)
        let popover = CGRect(x: 1800, y: -900, width: 320, height: 200)
        let layout = WindowComposite.layout(
            parent: onIt, children: [popover], scale: 1, within: below
        )
        #expect(layout.bounds == CGRect(x: 100, y: -1050, width: 1820, height: 1000))
        #expect(layout.flipped(in: below) == CGRect(x: 100, y: 50, width: 1820, height: 1000))
    }

    @Test func stagesOnlyAChildWithPixelsThatMeetsTheWindow() {
        #expect(WindowComposite.staged(child: CGRect(x: 400, y: 300, width: 300, height: 400), number: 12, with: main))
        #expect(!WindowComposite.staged(child: CGRect(x: 400, y: 300, width: 0, height: 400), number: 12, with: main))
        #expect(!WindowComposite.staged(child: CGRect(x: 400, y: 300, width: 300, height: 0), number: 12, with: main))
        #expect(!WindowComposite.staged(child: CGRect(x: 400, y: 300, width: 300, height: 400), number: 0, with: main))
        #expect(!WindowComposite.staged(child: CGRect(x: 5_000, y: 300, width: 300, height: 400), number: 12, with: main))
    }

}
