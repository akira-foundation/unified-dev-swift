import Testing
import Foundation
@testable import Core

@Suite("The transcript going blank when the composer is resized")
struct TranscriptBlankOnResizeTests {
    private func key(_ text: String) -> TranscriptContentKey {
        TranscriptContentKey { $0.combine(text) }
    }

    @Test("the end of a pane with no height is below the last row")
    func endOfAPaneWithNoHeightIsPastTheContent() {
        #expect(TranscriptAnchor.end(contentHeight: 30_000, viewportHeight: 0) == 30_000)
        #expect(
            TranscriptAnchor.clamped(30_000, contentHeight: 30_000, viewportHeight: 0) == 30_000
        )
    }

    @Test("nothing is placed against a pane that has not been laid out")
    func refusesAPaneWithNoHeight() {
        #expect(!TranscriptAnchor.canPlace(viewportHeight: 0))
        #expect(!TranscriptAnchor.canPlace(viewportHeight: 1))
        #expect(!TranscriptAnchor.canPlace(viewportHeight: -40))
    }

    @Test("a pane dragged down to its floor is still placed")
    func placesARealPane() {
        #expect(TranscriptAnchor.canPlace(viewportHeight: 120))
        #expect(TranscriptAnchor.canPlace(viewportHeight: 900))
    }

    @Test("a pass that cannot measure the chrome keeps the last one")
    func keepsAKnownChrome() {
        #expect(PaneMeasure.chrome(-30, knowing: 72) == 72)
        #expect(PaneMeasure.chrome(0, knowing: 72) == 72)
        #expect(PaneMeasure.chrome(90, knowing: 72) == 96)
    }

    @Test("a composer with nothing known yet still reports nothing")
    func keepsNothingWhenNothingIsKnown() {
        #expect(PaneMeasure.chrome(-30, knowing: 0) == 0)
    }

    @Test("a chrome of nought lets the composer take the whole transcript")
    func aChromeOfNoughtTakesTheFloor() {
        let room: CGFloat = 800
        let realChrome: CGFloat = 136
        let floor: CGFloat = 120
        let line: CGFloat = 20

        let honest = PaneMeasure.editorCap(
            room: room, chrome: realChrome, floor: floor, atLeast: line
        )
        #expect(room - (honest + realChrome) == floor)

        let lost = PaneMeasure.editorCap(room: room, chrome: 0, floor: floor, atLeast: line)
        #expect(room - (lost + realChrome) < 0)
    }

    @Test("a pane with no room caps nothing")
    func noRoomIsNoCap() {
        #expect(
            PaneMeasure.editorCap(room: 0, chrome: 72, floor: 120, atLeast: 20)
                == .greatestFiniteMagnitude
        )
    }

    @Test("the editor keeps a line in a pane with no room to spare")
    func keepsALine() {
        #expect(PaneMeasure.editorCap(room: 130, chrome: 72, floor: 120, atLeast: 20) == 20)
    }

    @Test("a resize that changes only the height keeps every measured row")
    func heightIsNotPartOfTheCache() {
        var heights = TranscriptRowHeights()
        let first = heights.reset(width: 900, scale: 1, leading: 1.7)
        #expect(first)
        heights.note(240, for: key("row.7"), shape: .answer, measuredAt: 900)
        heights.note(22, for: key("row.8"), shape: .fold, measuredAt: 900)

        let again = heights.reset(width: 900, scale: 1, leading: 1.7)
        #expect(!again)
        #expect(heights.height(for: key("row.7")) == 240)
        #expect(heights.height(for: key("row.8")) == 22)
        #expect(heights.count == 2)
    }

    @Test("a pane that is the same width owes no remeasurement")
    func rewidthIsAWidthQuestion() {
        var heights = TranscriptRowHeights()
        heights.reset(width: 900, scale: 1, leading: 1.7)
        heights.note(240, for: key("row.7"), shape: .answer, measuredAt: 900)

        let moved = heights.rewidth(to: 900)
        #expect(!moved)
        #expect(heights.staleCount == 0)
        #expect(heights.height(for: key("row.7")) == 240)
    }

    @Test("a cache that has a width never stops having one")
    func staysReady() {
        var heights = TranscriptRowHeights()
        heights.reset(width: 900, scale: 1, leading: 1.7)
        heights.note(240, for: key("row.7"), shape: .answer, measuredAt: 900)
        heights.forget()
        #expect(heights.isReady)
        let refused = heights.reset(width: 0.5, scale: 1, leading: 1.7)
        #expect(!refused)
        #expect(heights.isReady)
    }

    @Test("a resize silences no row that draws something")
    func silencesNothing() {
        var heights = TranscriptRowHeights()
        heights.reset(width: 900, scale: 1, leading: 1.7)
        heights.note(240, for: key("row.7"), shape: .answer, measuredAt: 900)
        heights.note(0, for: key("row.8"), shape: .notice, measuredAt: 900)

        let same = heights.reset(width: 900, scale: 1, leading: 1.7)
        #expect(!same)
        #expect(!heights.measuredNothing(key("row.7")))
        #expect(heights.measuredNothing(key("row.8")))
    }

    @Test("an unmeasured row is estimated rather than answered nothing")
    func unmeasuredRowsAreNeverNought() {
        var heights = TranscriptRowHeights()
        heights.reset(width: 900, scale: 1, leading: 1.7)
        heights.showing(SessionID("one"))
        for shape in TranscriptRowShape.allCases {
            #expect(heights.assumed(for: key("unseen.\(shape)"), shape: shape) > 0)
        }
        #expect(heights.assumed(for: key("unseen"), shape: .answer) > 0)
    }

    @Test("what a row draws is a question about the row, not about the pane")
    func inkIsAboutTheRow() {
        let ordinary = Data(#"{"type":"assistant","subtype":"text"}"#.utf8)
        #expect(!TranscriptRowInk.drawsNothing(kind: .assistantText, payload: ordinary))
        let start = Data(#"{"type":"system","subtype":"init"}"#.utf8)
        #expect(!TranscriptRowInk.drawsNothing(kind: .system, payload: start))
        let noise = Data(#"{"type":"system","subtype":"compact_boundary"}"#.utf8)
        #expect(TranscriptRowInk.drawsNothing(kind: .system, payload: noise))
    }
}
