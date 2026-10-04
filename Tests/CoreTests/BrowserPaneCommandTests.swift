import Foundation
import Testing
@testable import Core

private let waitsForThePage: [(BrowserPaneCommand, Bool)] = [
    (.read(nil), false),
    (.reload(1), false),
    (.go(1, "http://localhost:3000"), false),
    (.screenshot(nil), true),
    (.scroll(2, BrowserScroll(direction: .down, percent: 100)), true),
    (.text(1), true),
]

private let namesAnAddress: [(BrowserPaneCommand, String?)] = [
    (.go(1, "http://localhost:3000"), "http://localhost:3000"),
    (.read(nil), nil),
    (.reload(1), nil),
    (.screenshot(nil), nil),
    (.scroll(2, BrowserScroll(direction: .down, percent: 100)), nil),
    (.text(1), nil),
]

@Suite("Which browser tools wait for the page")
struct BrowserPaneCommandTests {
    @Test(
        "reading or moving the page waits for it; reporting, reloading and navigating do not",
        arguments: waitsForThePage
    )
    func readsPage(command: BrowserPaneCommand, waits: Bool) {
        #expect(command.readsPage == waits, "\(command.toolName)")
    }

    @Test(
        "only browser_go carries an address the person approved",
        arguments: namesAnAddress
    )
    func approvedAddress(command: BrowserPaneCommand, address: String?) {
        #expect(command.approvedAddress == address, "\(command.toolName)")
    }

    @Test("every tool that acts on an element waits for a load in progress first", arguments: [
        BrowserPaneCommand.outline(nil),
        .click(nil, BrowserAgentReference(index: 1)),
        .fill(nil, BrowserAgentReference(index: 1), "text"),
        .press(nil, .enter, nil),
    ])
    func actingWaitsForThePage(command: BrowserPaneCommand) {
        #expect(command.readsPage)
        #expect(command.approvedAddress == nil)
    }

    @Test("browser_wait is not made to wait twice, because the waiting is what it is for")
    func waitingIsNotDoneTwice() {
        let command = BrowserPaneCommand.wait(nil, .text("Saved"), seconds: 5)

        #expect(!command.readsPage)
        #expect(command.approvedAddress == nil)
    }

    @Test("each acting command carries the name of the tool that made it")
    func actingCommandsKnowTheirTool() {
        #expect(BrowserPaneCommand.outline(nil).toolName == "browser_snapshot")
        #expect(BrowserPaneCommand.click(nil, BrowserAgentReference(index: 1)).toolName == "browser_click")
        #expect(BrowserPaneCommand.fill(nil, BrowserAgentReference(index: 1), "t").toolName == "browser_fill")
        #expect(BrowserPaneCommand.press(nil, .enter, nil).toolName == "browser_press")
        #expect(BrowserPaneCommand.wait(nil, .load, seconds: 5).toolName == "browser_wait")
    }

    @Test("an acting command keeps the browser number it was given")
    func actingCommandsKeepTheirBrowser() {
        #expect(BrowserPaneCommand.outline(3).number == 3)
        #expect(BrowserPaneCommand.click(2, BrowserAgentReference(index: 1)).number == 2)
    }

    @Test("a script knows which element it was pointed at, and the page wide ones at none")
    func scriptsKnowTheirReference() {
        #expect(BrowserAgentScript.click(BrowserAgentReference(index: 4)).reference?.index == 4)
        #expect(BrowserAgentScript.fill(BrowserAgentReference(index: 5), "t").reference?.index == 5)
        #expect(BrowserAgentScript.press(.tab, BrowserAgentReference(index: 6)).reference?.index == 6)
        #expect(BrowserAgentScript.press(.tab, nil).reference == nil)
        #expect(BrowserAgentScript.outline.reference == nil)
        #expect(BrowserAgentScript.settled(.load).reference == nil)
    }
}
