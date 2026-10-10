import Foundation
import Testing
@testable import Core

@Suite("References to elements on a page")
struct BrowserAgentReferenceTests {
    @Test("a reference reads the way a snapshot writes it")
    func readsItsOwnSpelling() {
        let reference = BrowserAgentReference(index: 7)

        #expect(reference.token == "e7")
        #expect(BrowserAgentReference("e7") == reference)
        #expect(BrowserAgentReference("[e7]") == reference)
        #expect(BrowserAgentReference(" e7 ") == reference)
        #expect(BrowserAgentReference("E7") == reference)
    }

    @Test("anything that is not a reference is refused rather than guessed at", arguments: [
        "", "e", "7", "e0", "e-1", "e7x", "button", "e 7", "e7e8", "#submit", ".btn", "e٧",
    ])
    func refusesEverythingElse(raw: String) {
        #expect(BrowserAgentReference(raw) == nil)
    }

    @Test("a fresh page holds no references at all")
    func nothingBeforeASnapshot() {
        let handles = BrowserAgentHandles()
        let refusal = handles.refusal(for: BrowserAgentReference(index: 1), tool: "browser_click")

        #expect(handles.count == 0)
        #expect(refusal?.contains("browser_snapshot") == true)
    }

    @Test("a snapshot hands out the references it counted, and no more")
    func onlyWhatWasCounted() {
        var handles = BrowserAgentHandles()
        handles.recorded(count: 3)

        #expect(handles.refusal(for: BrowserAgentReference(index: 1), tool: "browser_click") == nil)
        #expect(handles.refusal(for: BrowserAgentReference(index: 3), tool: "browser_click") == nil)
        let tooFar = handles.refusal(for: BrowserAgentReference(index: 4), tool: "browser_click")
        #expect(tooFar?.contains("3") == true)
    }

    @Test("a second snapshot replaces the list, so a reference always means the newest one")
    func aSecondSnapshotReplacesTheList() {
        var handles = BrowserAgentHandles()
        handles.recorded(count: 3)
        handles.recorded(count: 1)

        #expect(handles.count == 1)
        #expect(handles.refusal(for: BrowserAgentReference(index: 1), tool: "browser_fill") == nil)
        #expect(handles.refusal(for: BrowserAgentReference(index: 3), tool: "browser_fill") != nil)
    }

    @Test("the register never hands out more references than the snapshot printed")
    func noMoreThanTheOutlinePrinted() {
        var handles = BrowserAgentHandles()
        handles.recorded(count: 9_000)

        #expect(handles.count == BrowserPageOutline.elementLimit)
        let past = handles.refusal(
            for: BrowserAgentReference(index: BrowserPageOutline.elementLimit + 1),
            tool: "browser_click"
        )
        #expect(past != nil)
    }

    @Test("a page that navigated refuses every reference until the next snapshot")
    func navigationKillsThemAll() {
        var handles = BrowserAgentHandles()
        handles.recorded(count: 3)
        handles.pageChanged()

        let refusal = handles.refusal(for: BrowserAgentReference(index: 1), tool: "browser_press")
        #expect(refusal?.contains("browser_snapshot") == true)
        #expect(handles.count == 0)
    }
}
