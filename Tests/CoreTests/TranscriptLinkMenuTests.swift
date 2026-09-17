import Foundation
import Testing
@testable import Core

@Suite("Transcript link menu")
struct TranscriptLinkMenuTests {
    private func items(_ address: String, _ placement: TranscriptLinkPlacement) throws -> [TranscriptLinkItem] {
        let url = try #require(URL(string: address))
        return TranscriptLinkMenu.items(for: url, placement: placement)
    }

    private func titles(_ address: String, _ placement: TranscriptLinkPlacement) throws -> [String] {
        try items(address, placement).map(\.title)
    }

    @Test("A page in a pane offers the external browser, a tab, and both splits, in that order")
    func inAPane() throws {
        #expect(try titles("https://example.com/page", .pane) == [
            "Open in External Browser",
            "Open in Browser Tab",
            "Open in Split Right",
            "Open in Split Down",
        ])
    }

    @Test("Split Right is the axis that lays two panes side by side")
    func theAxesAreTheRightWayRound() throws {
        let targets = try items("https://example.com", .pane).map(\.target)
        #expect(targets == [
            .externalBrowser, .browserTab, .split(.horizontal), .split(.vertical),
        ])
    }

    @Test("A transcript the window cannot name a pane for offers a tab but no split")
    func aColumnWithNoPane() throws {
        #expect(try titles("https://example.com/page", .column) == [
            "Open in External Browser",
            "Open in Browser Tab",
        ])
    }

    @Test("A transcript with no column behind it offers the external browser alone")
    func detached() throws {
        for address in ["https://example.com/page", "http://localhost:3100", "mailto:a@b.example"] {
            #expect(try titles(address, .detached) == ["Open in External Browser"])
        }
    }

    @Test("An address no browser of Unified Dev's own could show offers only the external browser",
          arguments: ["mailto:owner@example.com", "ftp://example.com/file", "javascript:alert(1)"])
    func addressesNoPaneCanShow(address: String) throws {
        for placement in TranscriptLinkPlacement.allCases {
            #expect(try titles(address, placement) == ["Open in External Browser"])
        }
    }

    @Test("A local dev server is a page like any other, splits included")
    func localhostSplits() throws {
        #expect(try items("http://localhost:3100/orders", .pane).count == 4)
    }

    @Test("Every placement offers the external browser, so a link is never a menu of nothing")
    func theExternalBrowserIsAlwaysThere() throws {
        for placement in TranscriptLinkPlacement.allCases {
            #expect(try items("https://example.com", placement).first?.target == .externalBrowser)
        }
    }

    @Test("A destination is never offered twice")
    func noDuplicates() throws {
        for placement in TranscriptLinkPlacement.allCases {
            let offered = try items("https://example.com", placement)
            #expect(Set(offered.map(\.id)).count == offered.count)
        }
    }

    @Test("The three placements nest")
    func placementsNest() throws {
        let detached = try items("https://example.com", .detached)
        let column = try items("https://example.com", .column)
        let pane = try items("https://example.com", .pane)
        #expect(column.starts(with: detached))
        #expect(pane.starts(with: column))
    }
}

@Suite("Browser address")
struct BrowserAddressShowsTests {
    @Test("Web schemes are shown", arguments: [
        "https://example.com/page",
        "http://localhost:3100",
        "HTTPS://EXAMPLE.COM",
        "http://127.0.0.1:8080/admin",
    ])
    func shown(address: String) throws {
        #expect(BrowserAddress.shows(try #require(URL(string: address))))
    }

    @Test("Everything else is not", arguments: [
        "mailto:owner@example.com",
        "file:///Applications/Something.app",
        "ftp://example.com/file",
        "x-apple.systempreferences:com.apple.preference",
    ])
    func notShown(address: String) throws {
        #expect(!BrowserAddress.shows(try #require(URL(string: address))))
    }
}
