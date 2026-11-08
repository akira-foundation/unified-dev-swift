import Foundation
import Testing
@testable import Core

@Suite("Browser pane access")
struct BrowserPaneAccessTests {
    @Test("A pane with no stored access, or one this build cannot read, stays the owner's")
    func unknownAccessIsTheOwners() {
        #expect(BrowserPaneAccess.restored(nil) == .owner)
        #expect(BrowserPaneAccess.restored("everyone") == .owner)
        #expect(BrowserPaneAccess.restored("") == .owner)
    }

    @Test("A stored access reads back as itself", arguments: BrowserPaneAccess.allCases)
    func storedAccessRoundTrips(access: BrowserPaneAccess) {
        #expect(BrowserPaneAccess.restored(access.rawValue) == access)
    }

    @Test("The owner keeps the storage panes have always used")
    func theOwnerKeepsTheStandardStorage() {
        #expect(BrowserPaneAccess.owner.storage == .standard)
        #expect(!BrowserPaneAccess.owner.isOpenToAgents)
    }

    @Test("Agents get one storage of their own, with an identifier that never changes")
    func agentsHaveAStableDedicatedStorage() throws {
        let identifier = try #require(UUID(uuidString: "E74A1C52-9B3D-4F86-A211-6D0C5E8F47B3"))
        #expect(BrowserPaneAccess.agents.storage == .dedicated(identifier))
        #expect(BrowserPaneAccess.agents.isOpenToAgents)
    }
}
