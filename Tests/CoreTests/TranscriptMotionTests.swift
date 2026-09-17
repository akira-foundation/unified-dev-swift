import Testing
import Foundation
@testable import Core

@Suite("What the transcript animates")
struct TranscriptMotionTests {
    @Test("a row that lands where something else was fades in")
    func rowsThatFade() {
        #expect(TranscriptMotion.fadesOnArrival(.toolUse))
        #expect(TranscriptMotion.fadesOnArrival(.toolResult))
        #expect(TranscriptMotion.fadesOnArrival(.permissionAsk))
        #expect(TranscriptMotion.fadesOnArrival(.result))
        #expect(TranscriptMotion.fadesOnArrival(.error))
        #expect(TranscriptMotion.fadesOnArrival(.system))
        #expect(TranscriptMotion.fadesOnArrival(.notice))
    }

    @Test("a row that replaces something already drawn does not")
    func rowsThatDoNotFade() {
        #expect(!TranscriptMotion.fadesOnArrival(.assistantText))
        #expect(!TranscriptMotion.fadesOnArrival(.thinking))
        #expect(!TranscriptMotion.fadesOnArrival(.user))
    }

    @Test("Reduce Motion is taken there instantly")
    func reduceMotionJumps() {
        #expect(TranscriptMotion.liveEndMove(distance: 5000, reduceMotion: true) == .jump)
        #expect(TranscriptMotion.liveEndMove(distance: 200, reduceMotion: true) == .jump)
    }

    @Test("a reader who is already at the end is not taken on a journey")
    func nowhereToGo() {
        #expect(TranscriptMotion.liveEndMove(distance: 0, reduceMotion: false) == .jump)
        #expect(TranscriptMotion.liveEndMove(distance: -40, reduceMotion: false) == .jump)
        #expect(TranscriptMotion.liveEndMove(distance: 95, reduceMotion: false) == .jump)
    }

    @Test("the glide is nearly the same length however far it has to go")
    func nearlyConstantDuration() {
        let near = seconds(TranscriptMotion.liveEndMove(distance: 200, reduceMotion: false))
        let far = seconds(TranscriptMotion.liveEndMove(distance: 20_000, reduceMotion: false))

        #expect(near > 0)
        #expect(far > near)
        #expect(far / near < 2)
        #expect(far <= 0.3)
    }

    @Test("the glide never runs past its ceiling or under its floor")
    func bounded() {
        for distance in stride(from: 96.0, through: 40_000, by: 137) {
            let length = seconds(TranscriptMotion.liveEndMove(distance: distance, reduceMotion: false))
            #expect(length >= TranscriptMotion.glideFloor)
            #expect(length <= TranscriptMotion.glideCeiling)
        }
    }

    @Test("past the ramp the answer stops moving")
    func saturates() {
        let atRamp = TranscriptMotion.liveEndMove(distance: TranscriptMotion.glideRamp, reduceMotion: false)
        let farPast = TranscriptMotion.liveEndMove(distance: TranscriptMotion.glideRamp * 30, reduceMotion: false)
        #expect(atRamp == farPast)
        #expect(atRamp == .glide(seconds: TranscriptMotion.glideCeiling))
    }

    private func seconds(_ move: TranscriptMotion.LiveEndMove) -> Double {
        switch move {
        case .jump: 0
        case .glide(let seconds): seconds
        }
    }

    @Test("a settle has both a length and some travel, and neither is an effect")
    func settleShape() throws {
        let settle = try #require(TranscriptMotion.arrival(reduceMotion: false))
        #expect(settle.rise > 0)
        #expect(settle.rise < 12)
        #expect(settle.seconds > 0.1)
        #expect(settle.seconds < 0.4)
    }

    @Test("Reduce Motion is owed no settle at all")
    func settleUnderReduceMotion() {
        #expect(TranscriptMotion.arrival(reduceMotion: true) == nil)
    }

    @Test("exactly the three rows that are already on screen refuse to fade")
    func onlyTheEchoedKindsRefuseTheFade() {
        let still = MessageKind.allCases.filter { !TranscriptMotion.fadesOnArrival($0) }
        #expect(Set(still) == [.assistantText, .thinking, .user])
        #expect(still.count + MessageKind.allCases.count(where: TranscriptMotion.fadesOnArrival)
            == MessageKind.allCases.count)
    }
}
