import Foundation
import Testing
@testable import Core

@Suite("Link opening")
struct LinkOpeningTests {
    private func target(
        _ address: String,
        placement: TranscriptLinkPlacement = .pane,
        isEnabled: Bool = true,
        asksForExternal: Bool = false
    ) throws -> TranscriptLinkTarget {
        let url = try #require(URL(string: address))
        return LinkOpening.target(
            for: url, placement: placement, isEnabled: isEnabled, asksForExternal: asksForExternal
        )
    }

    @Test("A web address opens in the built-in browser wherever a workspace is behind the link",
          arguments: ["https://example.com/page", "http://localhost:55190/?key=abc"],
          [TranscriptLinkPlacement.column, .pane])
    func webAddressesStayInside(address: String, placement: TranscriptLinkPlacement) throws {
        #expect(try target(address, placement: placement) == .browserTab)
    }

    @Test("Turning the setting off sends every link to the default browser")
    func theSettingTurnsItOff() throws {
        #expect(try target("https://example.com", isEnabled: false) == .externalBrowser)
    }

    @Test("Asking for the default browser beats the setting")
    func anExplicitRequestWins() throws {
        #expect(try target("https://example.com", asksForExternal: true) == .externalBrowser)
    }

    @Test("With no workspace there is no browser to open it in")
    func detachedGoesOutside() throws {
        #expect(try target("https://example.com", placement: .detached) == .externalBrowser)
    }

    @Test("An address the built-in browser cannot show goes outside",
          arguments: ["mailto:owner@example.com", "file:///tmp/report.html", "/tmp/report.html"])
    func unshowableGoesOutside(address: String) throws {
        #expect(try target(address) == .externalBrowser)
    }

    @Test("It is on unless somebody turned it off")
    func onByDefault() {
        #expect(LinkOpening.isOnByDefault)
    }

    @Test("A tab already showing the address is the one to reveal, the last of several")
    func reusesTheMatchingTab() {
        let open = ["https://example.com/a", "https://example.com/b", "https://example.com/a"]
        #expect(LinkOpening.tab(showing: "https://example.com/a", among: open) == 2)
    }

    @Test("A different address never takes over an open tab")
    func aDifferentPageKeepsItsTab() {
        let open = ["https://example.com/a", "http://localhost:3000/?key=1"]
        #expect(LinkOpening.tab(showing: "https://example.com/b", among: open) == nil)
        #expect(LinkOpening.tab(showing: "http://localhost:3000/?key=2", among: open) == nil)
    }

    @Test("A bare host and its root are the same page")
    func aTrailingSlashIsTheSamePage() {
        #expect(LinkOpening.tab(showing: "http://localhost:3000", among: ["http://localhost:3000/"]) == 0)
    }

    @Test("A tab with no address yet is not a match")
    func aBlankTabIsNoMatch() {
        #expect(LinkOpening.tab(showing: "https://example.com", among: [""]) == nil)
    }
}
