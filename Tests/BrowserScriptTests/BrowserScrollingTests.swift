@testable import Core
import Testing

@MainActor
@Suite("What the scrolling script moves and reports", .serialized)
struct BrowserScrollingTests {
    private static let tall = "<div style=\"height: 6000px\">Top of it</div><p>Bottom of it</p>"

    @Test("a scroll reports where the view now is, how tall the page is and how much it shows")
    func aScrollReportsTheViewport() async throws {
        let page = try await BrowserPageFixture.body(Self.tall)

        let start = try await page.scrolled(BrowserScroll(direction: .top))

        #expect(start.offset == 0)
        #expect(start.height > 6_000)
        #expect(start.viewport == 800)
    }

    @Test("one screenful down is one viewport, and the percentage is what moves")
    func aScreenfulIsTheViewport() async throws {
        let page = try await BrowserPageFixture.body(Self.tall)
        _ = try await page.scrolled(BrowserScroll(direction: .top))

        let one = try await page.scrolled(BrowserScroll(direction: .down))
        #expect(one.offset == one.viewport)

        _ = try await page.scrolled(BrowserScroll(direction: .top))
        let half = try await page.scrolled(BrowserScroll(direction: .down, percent: 50))
        #expect(half.offset == one.viewport / 2)
    }

    @Test("up moves back by the same measure, and never past the top")
    func upComesBack() async throws {
        let page = try await BrowserPageFixture.body(Self.tall)
        let down = try await page.scrolled(BrowserScroll(direction: .down, percent: 200))
        #expect(down.offset == down.viewport * 2)

        let up = try await page.scrolled(BrowserScroll(direction: .up))
        #expect(up.offset == down.viewport)

        let further = try await page.scrolled(BrowserScroll(direction: .up, percent: 2_000))
        #expect(further.offset == 0)
    }

    @Test("the bottom is the bottom, and the report says the view is at it")
    func theBottomIsTheBottom() async throws {
        let page = try await BrowserPageFixture.body(Self.tall)

        let bottom = try await page.scrolled(BrowserScroll(direction: .bottom))
        let said = BrowserScroll(direction: .bottom)
            .report(offset: bottom.offset, height: bottom.height, viewport: bottom.viewport)

        #expect(bottom.offset + bottom.viewport >= bottom.height - 2)
        #expect(said.contains("at the bottom"))
    }

    @Test("a page that fits on one screen reports no distance to travel")
    func aShortPageDoesNotMove() async throws {
        let page = try await BrowserPageFixture.body("<p>All of it.</p>")

        let moved = try await page.scrolled(BrowserScroll(direction: .down))

        #expect(moved.offset == 0)
        #expect(moved.height <= moved.viewport)
    }

    @Test("the words a scroll leaves on screen are the words a snapshot and a wait then read")
    func scrollingChangesWhatIsRead() async throws {
        let page = try await BrowserPageFixture.body(Self.tall)
        _ = try await page.scrolled(BrowserScroll(direction: .top))

        #expect(try await page.visibleText().contains("Top of it"))
        #expect(try await page.reading(.text("Bottom of it")) == .met)

        let bottom = try await page.scrolled(BrowserScroll(direction: .bottom))
        #expect(bottom.offset > 0)
    }
}
