import Foundation
import Testing
@testable import Core

@Suite("The crest that travels the activity rule")
struct BusyCrestTests {
    @Test("it is nothing at either end and the accent at its peak")
    func endsAtNothing() {
        #expect(BusyCrest.profile(atFraction: 0) == 0)
        #expect(BusyCrest.profile(atFraction: 1) == 0)
        #expect(abs(BusyCrest.profile(atFraction: BusyCrest.peak) - 1) < 1e-12)
        #expect(BusyCrest.peakOpacity == 1)
    }

    @Test("it rises to the peak and falls away from it, and never leaves the range")
    func risesAndFalls() {
        var previous = BusyCrest.profile(atFraction: 0)
        for step in 1...1000 {
            let fraction = Double(step) / 1000
            let value = BusyCrest.profile(atFraction: fraction)
            #expect(value >= 0 && value <= 1)
            if fraction <= BusyCrest.peak {
                #expect(value >= previous - 1e-12, "the face should not dip on its way up")
            } else {
                #expect(value <= previous + 1e-12, "the tail should not lift on its way down")
            }
            previous = value
        }
    }

    @Test("the tail behind the peak is longer than the face in front of it")
    func isAsymmetric() {
        let behind = BusyCrest.peak - firstFraction(reaching: 0.5, from: 0, to: BusyCrest.peak)
        let ahead = firstFraction(reaching: 0.5, from: 1, to: BusyCrest.peak) - BusyCrest.peak
        #expect(behind > ahead * 2, "a head this soft says nothing about which way it is going")
    }

    @Test("the stops span the crest in order")
    func stopsAreOrdered() {
        let stops = BusyCrest.stops()
        #expect(stops.count > 2)
        #expect(stops.first?.location == 0)
        #expect(stops.last?.location == 1)
        #expect(stops.first?.opacity == 0)
        #expect(stops.last?.opacity == 0)
        for pair in zip(stops, stops.dropFirst()) {
            #expect(pair.1.location > pair.0.location)
        }
    }

    @Test("the train tiles the same crest and closes on itself")
    func trainTiles() {
        let stops = BusyCrest.waveStops(wavelengths: 3, samplesEach: 12)
        #expect(stops.count == 37)
        #expect(stops.first?.location == 0)
        #expect(stops.last?.location == 1)
        #expect(stops.first?.opacity == stops.last?.opacity)
        for pair in zip(stops, stops.dropFirst()) {
            #expect(pair.1.location > pair.0.location)
        }
        for step in 0..<12 {
            #expect(abs(stops[step].opacity - stops[step + 12].opacity) < 1e-12)
            #expect(abs(stops[step].opacity - stops[step + 24].opacity) < 1e-12)
        }
    }

    @Test("it begins and ends entirely off the rule")
    func travelsClearOfBothEnds() {
        let travel = BusyCrest.travel(alongWidth: 900)
        #expect(travel.lowerBound + BusyCrest.length / 2 <= 0)
        #expect(travel.upperBound - BusyCrest.length / 2 >= 900)
    }

    @Test("a rule with no width still gives a range")
    func travelSurvivesNoWidth() {
        let travel = BusyCrest.travel(alongWidth: 0)
        #expect(travel.lowerBound <= travel.upperBound)
        #expect(BusyCrest.travel(alongWidth: -50).lowerBound <= BusyCrest.travel(alongWidth: -50).upperBound)
    }

    @Test("held still, the crest parks its head at the trailing edge")
    func restsAtTheTrailingEdge() {
        let centre = BusyCrest.restingCentre(alongWidth: 900)
        #expect(centre + BusyCrest.length / 2 == 900)
        #expect(centre - BusyCrest.length / 2 >= 0)
    }

    @Test("a rule shorter than the crest gets it centred")
    func restsCentredOnAShortRule() {
        let width = BusyCrest.length / 2
        #expect(BusyCrest.restingCentre(alongWidth: width) == width / 2)
        #expect(BusyCrest.restingCentre(alongWidth: 0) == 0)
    }

    @Test("the train covers the rule with a wavelength to spare")
    func trainCoversTheRule() {
        for width in [0.0, 100, 380, 900, 2000] {
            let count = BusyCrest.wavelengths(alongWidth: width)
            #expect(count >= 2)
            #expect(Double(count) * BusyCrest.waveLength >= width + BusyCrest.waveLength - 1e-9)
        }
    }

    @Test("the crest and the train are both on the window's heartbeat")
    func staysOnTheHeartbeat() {
        #expect((BusyCrest.period / BusyDot.period).truncatingRemainder(dividingBy: 1) == 0)
        #expect((BusyCrest.period / BusyCrest.wavePeriod).truncatingRemainder(dividingBy: 1) == 0)
        #expect(BusyCrest.wavePeriod == BusyDot.period)
    }

    @Test("it is lit everywhere and thicker than the rule it rides")
    func answersTheComplaint() {
        #expect(BusyCrest.trackOpacity > BusyRule.restingOpacity)
        #expect(BusyCrest.trackOpacity < BusyCrest.peakOpacity)
        #expect(BusyCrest.thickness > BusyRule.restingHeight)
        #expect(BusyCrest.glowHeight < BusyCrest.thickness)
        #expect(BusyCrest.glowShare < 1, "a glow as strong as the core is a thicker core")
    }

    private func firstFraction(reaching value: Double, from: Double, to: Double) -> Double {
        let steps = 10_000
        for step in 0...steps {
            let fraction = from + (to - from) * Double(step) / Double(steps)
            if BusyCrest.profile(atFraction: fraction) >= value { return fraction }
        }
        return to
    }
}
