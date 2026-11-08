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
}
