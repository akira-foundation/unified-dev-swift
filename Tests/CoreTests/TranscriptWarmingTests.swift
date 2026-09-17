import Testing
import Foundation
@testable import Core

@Suite("Preparing rows before a reader reaches them")
struct TranscriptWarmingTests {
    @Test("the reach is two screens")
    func reachIsTwoScreens() {
        #expect(TranscriptWarming.reach(viewport: 700) == 1_400)
        #expect(TranscriptWarming.reach(viewport: 300) == 600)
    }

    @Test("the reach stops at the ceiling")
    func reachStopsAtTheCeiling() {
        #expect(TranscriptWarming.reach(viewport: 1_600) == TranscriptWarming.ceiling)
        #expect(TranscriptWarming.reach(viewport: 4_000) == TranscriptWarming.ceiling)
    }

    @Test("a pane with no height reaches nowhere")
    func noViewportNoReach() {
        #expect(TranscriptWarming.reach(viewport: 0) == 0)
        #expect(TranscriptWarming.reach(viewport: -10) == 0)
    }

    @Test("a band wider than the cap is cut to the rows nearest the reader")
    func aWideBandIsCut() {
        let band = 100..<900
        let warming = TranscriptWarming.worthWarming(band)
        #expect(warming.count == TranscriptWarming.mostRows)
        #expect(warming.upperBound == 900)
        #expect(warming.lowerBound == 900 - TranscriptWarming.mostRows)
    }

    @Test("a band inside the cap is taken whole")
    func aNarrowBandIsWhole() {
        let band = 10..<40
        #expect(TranscriptWarming.worthWarming(band) == band)
    }

    @Test("an empty band prepares nothing")
    func anEmptyBandIsNothing() {
        #expect(TranscriptWarming.worthWarming(7..<7).isEmpty)
    }

    @Test("a cap of nothing prepares nothing")
    func noCapPreparesNothing() {
        #expect(TranscriptWarming.worthWarming(0..<500, most: 0).isEmpty)
    }
}
