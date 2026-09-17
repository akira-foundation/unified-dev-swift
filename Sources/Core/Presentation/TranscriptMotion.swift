import Foundation

public enum TranscriptMotion {
    public static func fadesOnArrival(_ kind: MessageKind) -> Bool {
        switch kind {
        case .assistantText, .thinking, .user: false
        case .toolUse, .toolResult, .permissionAsk, .result, .error, .system, .notice, .crew: true
        }
    }

    public struct Arrival: Equatable, Sendable {
        public let seconds: Double

        public let rise: Double
    }

    public static func arrival(reduceMotion: Bool) -> Arrival? {
        guard !reduceMotion else { return nil }
        return Arrival(seconds: 0.25, rise: 10)
    }

    public static func disclosure(reduceMotion: Bool) -> Double? {
        arrival(reduceMotion: reduceMotion)?.seconds
    }

    public enum LiveEndMove: Equatable, Sendable {
        case jump
        case glide(seconds: Double)
    }

    public static let glideFloor: Double = 0.16

    public static let glideCeiling: Double = 0.26

    public static let glideRamp: Double = 1400

    public static let glideFloorDistance: Double = ScrollEnd.threshold

    public static func liveEndMove(distance: Double, reduceMotion: Bool) -> LiveEndMove {
        guard !reduceMotion else { return .jump }
        guard distance >= glideFloorDistance else { return .jump }
        let ramp = min(1, max(0, distance) / glideRamp)
        return .glide(seconds: glideFloor + (glideCeiling - glideFloor) * ramp)
    }
}
