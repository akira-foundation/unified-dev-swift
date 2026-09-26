import Testing
@testable import Core

@Suite("What the welcome window says the app does")
struct WelcomeHighlightTests {
    @Test("Three lines, in the order somebody meets them")
    func order() {
        #expect(WelcomeHighlight.all.count == 3)
        #expect(WelcomeHighlight.all.map(\.symbol) == [
            "arrow.trianglehead.branch", "sparkles", "arrow.trianglehead.pull",
        ])
    }

    @Test("No line is half written")
    func complete() {
        for highlight in WelcomeHighlight.all {
            #expect(!highlight.symbol.isEmpty)
            #expect(!highlight.headline.isEmpty)
            #expect(!highlight.detail.isEmpty)
        }
    }

    @Test("A headline is a phrase and a detail is a sentence")
    func shape() {
        for highlight in WelcomeHighlight.all {
            #expect(!highlight.headline.hasSuffix("."))
            #expect(highlight.detail.hasSuffix("."))
        }
    }

    @Test("Each line is its own identity")
    func identity() {
        #expect(Set(WelcomeHighlight.all.map(\.id)).count == 3)
    }
}
