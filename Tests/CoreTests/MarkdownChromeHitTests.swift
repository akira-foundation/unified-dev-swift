import CoreGraphics
import Testing
@testable import Core

@Suite struct MarkdownChromeHitTests {
    private let controls = CGRect(x: 600, y: 6, width: 48, height: 20)

    @Test func aPointOverAControlStaysWithTheChromeEvenWhenTheHostAnswers() {
        #expect(MarkdownChromeHit.keeps(hitIsHost: true, point: CGPoint(x: 610, y: 10), controls: controls))
    }

    @Test func aPointBesideTheControlsFallsThroughToTheText() {
        #expect(!MarkdownChromeHit.keeps(hitIsHost: true, point: CGPoint(x: 20, y: 10), controls: controls))
    }

    @Test func aChromeWithNoControlsKeepsNothingOfItsOwn() {
        #expect(!MarkdownChromeHit.keeps(hitIsHost: true, point: CGPoint(x: 610, y: 10), controls: .null))
    }

    @Test func aRealSubviewAlwaysKeepsItsHit() {
        #expect(MarkdownChromeHit.keeps(hitIsHost: false, point: CGPoint(x: 20, y: 10), controls: .null))
    }

    @Test("text outside any scroll view is visible where it sits")
    func unclippedTextStaysWhereItIs() {
        let frame = CGRect(x: 12, y: 27, width: 120, height: 50)
        #expect(MarkdownChromeHit.visibleText(frame: frame, scrollBounds: nil) == frame)
    }

    @Test("scrolled text only counts where the scroll view still shows it")
    func scrolledTextIsClipped() {
        let frame = CGRect(x: 12, y: -30, width: 120, height: 300)
        let visible = MarkdownChromeHit.visibleText(frame: frame, scrollBounds: CGRect(x: 0, y: 30, width: 120, height: 100))
        #expect(visible == CGRect(x: 12, y: 0, width: 120, height: 100))
    }

    @Test("text scrolled right out of view takes no pointer at all")
    func textScrolledAwayIsNull() {
        let frame = CGRect(x: 12, y: 27, width: 120, height: 50)
        let visible = MarkdownChromeHit.visibleText(frame: frame, scrollBounds: CGRect(x: 500, y: 0, width: 10, height: 10))
        #expect(visible.isNull)
    }
}
