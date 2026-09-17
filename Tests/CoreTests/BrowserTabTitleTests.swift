import Testing
@testable import Core

@Suite("Browser tab title")
struct BrowserTabTitleTests {
    @Test("A page with a title is called by it")
    func usesThePageTitle() {
        #expect(
            BrowserTabTitle.title(page: "Akira", address: "https://akira-io.com/", fallback: "Browser")
                == "Akira"
        )
    }

    @Test("A page with no title falls back to the host, without its www")
    func fallsBackToTheHost() {
        #expect(
            BrowserTabTitle.title(page: "", address: "https://www.akira-io.com/about", fallback: "Browser")
                == "akira-io.com"
        )
    }

    @Test("A dev server keeps its port")
    func keepsThePort() {
        #expect(
            BrowserTabTitle.title(page: "", address: "http://localhost:3000/", fallback: "Browser")
                == "localhost:3000"
        )
    }

    @Test("A page with neither a title nor a host is the tab's own name")
    func fallsBackToTheTabName() {
        for address in ["about:blank", "", "file:///tmp/index.html"] {
            #expect(
                BrowserTabTitle.title(page: "", address: address, fallback: "Browser 2") == "Browser 2"
            )
        }
    }

    @Test("A title that only restates the address is not used")
    func ignoresTheAddressAsATitle() {
        #expect(
            BrowserTabTitle.title(
                page: "http://localhost:3000/", address: "http://localhost:3000/", fallback: "Browser"
            ) == "localhost:3000"
        )
        #expect(
            BrowserTabTitle.title(page: "akira-io.com", address: "https://akira-io.com/", fallback: "Browser")
                == "akira-io.com"
        )
    }

    @Test("A name the user typed beats anything the page says")
    func aTypedNameWins() {
        #expect(
            BrowserTabTitle.title(
                page: "Akira", address: "https://akira-io.com/", fallback: "Docs", isNamed: true
            ) == "Docs"
        )
    }

    @Test("A link followed inside a site keeps the title up while the next page loads")
    func holdsTheTitleWithinAHost() {
        #expect(BrowserTabTitle.survives(
            navigationFrom: "https://akira-io.com/", to: "https://akira-io.com/open-source"
        ))
        #expect(BrowserTabTitle.survives(
            navigationFrom: "http://localhost:3000/", to: "http://localhost:3000/settings"
        ))
    }

    @Test("Leaving a site drops its title at once")
    func dropsTheTitleAcrossHosts() {
        #expect(!BrowserTabTitle.survives(navigationFrom: "https://akira-io.com/", to: "https://github.com/"))
        #expect(!BrowserTabTitle.survives(navigationFrom: "https://akira-io.com/", to: "about:blank"))
        #expect(!BrowserTabTitle.survives(navigationFrom: "", to: "https://akira-io.com/"))
    }

    @Test("A different port is a different place")
    func portsAreDifferentPlaces() {
        #expect(!BrowserTabTitle.survives(
            navigationFrom: "http://localhost:3000/", to: "http://localhost:4000/"
        ))
    }

    private func page(_ address: String, _ title: String = "") -> BrowserTabTitle.BrowserPage {
        BrowserTabTitle.BrowserPage(address: address, title: title)
    }

    @Test("A title arriving for the page the tab has just moved to is kept")
    func adoptsATitleWithItsNavigation() {
        let next = BrowserTabTitle.advance(
            from: page("https://akira-io.com/", "Akira"),
            to: page("https://github.com/akira-io", "akira-io · GitHub")
        )
        #expect(next == page("https://github.com/akira-io", "akira-io · GitHub"))
    }

    @Test("A navigation with no title yet keeps the name while the page is on the same host")
    func holdsTheNameWhileLoading() {
        let next = BrowserTabTitle.advance(
            from: page("https://akira-io.com/", "Akira"), to: page("https://akira-io.com/open-source")
        )
        #expect(next == page("https://akira-io.com/open-source", "Akira"))
    }

    @Test("A navigation off the host drops the name at once")
    func dropsTheNameOnLeaving() {
        let next = BrowserTabTitle.advance(
            from: page("https://akira-io.com/", "Akira"), to: page("https://github.com/")
        )
        #expect(next == page("https://github.com/", ""))
    }

    @Test("A title changing with no navigation is taken")
    func adoptsATitleWithoutANavigation() {
        let next = BrowserTabTitle.advance(
            from: page("http://localhost:3000/", "Dashboard"),
            to: page("http://localhost:3000/", "Settings")
        )
        #expect(next == page("http://localhost:3000/", "Settings"))
    }

    @Test("A client side navigation moves the address and keeps the name up")
    func followsAPushState() {
        let next = BrowserTabTitle.advance(
            from: page("https://there-there-6.test/login", "Log in"),
            to: page("https://there-there-6.test/tickets/429")
        )
        #expect(next == page("https://there-there-6.test/tickets/429", "Log in"))

        let named = BrowserTabTitle.advance(from: next, to: page("", "#429 Large CSV support"))
        #expect(named == page("https://there-there-6.test/tickets/429", "#429 Large CSV support"))
    }

    @Test("A page with no address at all keeps the one the tab has")
    func keepsTheAddressWhenNoneIsGiven() {
        let next = BrowserTabTitle.advance(from: page("https://akira-io.com/", "Akira"), to: page(""))
        #expect(next == page("https://akira-io.com/", "Akira"))
    }

    @Test("A title is flattened to one line")
    func flattensToOneLine() {
        #expect(BrowserTabTitle.tidy("Akira\n\tweb development") == "Akira web development")
        #expect(BrowserTabTitle.tidy("  Akira   ") == "Akira")
        #expect(BrowserTabTitle.tidy(nil).isEmpty)
        #expect(BrowserTabTitle.tidy("   ").isEmpty)
    }

    @Test("A very long title is capped, at a word boundary where there is one")
    func caps() {
        let long = String(repeating: "word ", count: 200)
        let capped = BrowserTabTitle.tidy(long)
        #expect(capped.count <= BrowserTabTitle.limit + 1)
        #expect(capped.hasSuffix("…"))
        #expect(!capped.hasSuffix(" …"))

        let unbroken = String(repeating: "a", count: 400)
        #expect(BrowserTabTitle.tidy(unbroken).count == BrowserTabTitle.limit + 1)
    }

    @Test("A title that fits is left exactly as it is")
    func leavesShortTitlesAlone() {
        let title = "Akira: web development in Antwerp"
        #expect(BrowserTabTitle.tidy(title) == title)
    }
}
