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

    @Test("Sharing swaps the access both ways")
    func togglingSwaps() {
        #expect(BrowserPaneAccess.owner.toggled == .agents)
        #expect(BrowserPaneAccess.agents.toggled == .owner)
    }

    @Test("A shared pane keeps its address, and a pane taken back starts blank")
    func takingAPaneBackForgetsWhereAgentsLeftIt() {
        let address = "https://example.com"
        #expect(BrowserPaneAccess.agents.arrivalPage(from: address) == .init(address: address, title: ""))
        #expect(BrowserPaneAccess.owner.arrivalPage(from: address) == .init(address: "", title: ""))
    }

    @Test("Only a shared pane offers to be opened by the agent")
    func theEmptyPaneMessageFollowsTheAccess() {
        #expect(BrowserPaneAccess.owner.emptyPageMessage == "Type an address above.")
        #expect(BrowserPaneAccess.agents.emptyPageMessage.contains("ask the agent"))
    }

    @Test("Agents read an owner's pane under a name that says nothing about its page")
    func anOwnersPaneNameIsWithheld() {
        #expect(BrowserPaneAccess.owner.nameForAgents("Bank statement") == "Owner's browser")
        #expect(BrowserPaneAccess.agents.nameForAgents("Staging") == "Staging")
    }

    @Test("The toolbar marks a shared pane as active and an owner's pane as not")
    func theToolbarControlFollowsTheAccess() {
        let owners = BrowserToolbar.agentAccess(.owner)
        let shared = BrowserToolbar.agentAccess(.agents)
        #expect(owners.symbol == "eye.slash" && !owners.isActive)
        #expect(owners.name == "Share This Browser with Agents")
        #expect(shared.symbol == "eye" && shared.isActive)
        #expect(shared.name == "Stop Sharing This Browser with Agents")
    }

    @Test("A running download holds the access still, whichever way it would go", arguments: BrowserPaneAccess.allCases)
    func aDownloadBlocksTheSwitch(access: BrowserPaneAccess) {
        let held = BrowserToolbar.agentAccess(access, isDownloading: true)
        let free = BrowserToolbar.agentAccess(access)
        #expect(!held.isEnabled)
        #expect(free.isEnabled)
        #expect(held.symbol == free.symbol && held.name == free.name && held.isActive == free.isActive)
    }

    @Test("Refusing to close or rename an owner's browser names what did not happen")
    func thePaneRefusalSaysWhatDidNotHappen() {
        #expect(BrowserPaneAccess.paneRefusal(verb: "closed").hasSuffix("so it was not closed."))
    }

    @Test("The setting says agents cannot reach these tabs unless one is shared")
    func theSettingSaysSo() {
        #expect(LinkOpening.settingDetail.contains("Agents cannot read or use these tabs unless you share one"))
    }
}
