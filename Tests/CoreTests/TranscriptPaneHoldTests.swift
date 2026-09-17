import Testing
import Foundation
@testable import Core

@Suite("Holding a transcript back, and letting go of it")
struct TranscriptPaneHoldTests {
    @Test("a pane pointed at a conversation does not wait for ever")
    func revealsAnArrivalAnyway() {
        #expect(TranscriptPaneHold.arrival > .zero)
        #expect(TranscriptPaneHold.arrival <= .seconds(2))
    }

    @Test("a slow drag waits for the width to move a step before reflowing")
    func slowDragWaitsForAStep() {
        #expect(!TranscriptPaneHold.reflowsNow(from: 800, to: 801))
        #expect(!TranscriptPaneHold.reflowsNow(from: 800, to: 800 - TranscriptPaneHold.reflowStep + 1))
    }

    @Test("a step either way reflows on the frame")
    func aStepReflows() {
        #expect(TranscriptPaneHold.reflowsNow(from: 800, to: 800 + TranscriptPaneHold.reflowStep))
        #expect(TranscriptPaneHold.reflowsNow(from: 800, to: 800 - TranscriptPaneHold.reflowStep))
        #expect(TranscriptPaneHold.reflowsNow(from: 800, to: 640))
    }

    @Test("the width settles quickly once the hand stops")
    func settlesQuickly() {
        #expect(TranscriptPaneHold.settle > .zero)
        #expect(TranscriptPaneHold.settle <= .milliseconds(300))
    }

    @Test("what the reader can see is measured, and a screen either side of it")
    func measuresAroundTheReader() {
        let rows = TranscriptPaneHold.eager(visible: 400..<420, count: 1_855)
        #expect(rows == 380..<440)
    }

    @Test("the margin stops at the ends of the conversation")
    func clampsToTheList() {
        #expect(TranscriptPaneHold.eager(visible: 0..<10, count: 40) == 0..<20)
        #expect(TranscriptPaneHold.eager(visible: 30..<40, count: 40) == 20..<40)
    }

    @Test("the margin is capped, and never at the cost of what is visible")
    func capsTheMargin() {
        let rows = TranscriptPaneHold.eager(visible: 500..<1_000, count: 2_000)
        #expect(rows.lowerBound == 500 - TranscriptPaneHold.margin)
        #expect(rows.upperBound == 1_000 + TranscriptPaneHold.margin)
        #expect(rows.contains(500))
        #expect(rows.contains(999))
    }

    @Test("a pane with nothing on screen measures nothing")
    func measuresNothingForAnEmptyPane() {
        #expect(TranscriptPaneHold.eager(visible: 0..<0, count: 1_855).isEmpty)
        #expect(TranscriptPaneHold.eager(visible: 0..<10, count: 0).isEmpty)
    }
}
