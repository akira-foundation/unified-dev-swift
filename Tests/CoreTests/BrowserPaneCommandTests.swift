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
}
