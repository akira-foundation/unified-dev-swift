import Foundation

public enum BusyCrest {
    public struct Stop: Equatable, Sendable {
        public let location: Double
        public let opacity: Double

        public init(location: Double, opacity: Double) {
            self.location = location
            self.opacity = opacity
        }
    }

    public static let length = 190.0

    public static let thickness = 3.0

    public static let glowHeight = 2.0

    public static let glowShare = 0.5

    public static let trackOpacity = 0.42

    public static let peakOpacity = 1.0

    public static let peak = 0.78

    public static var period: TimeInterval { BusyBreath.period }

    public static let waveLength = 120.0

    public static var wavePeriod: TimeInterval { BusyDot.period }

    public static func profile(atFraction fraction: Double) -> Double {
        let f = min(max(fraction, 0), 1)
        if f >= peak {
            return smoothstep((1 - f) / (1 - peak))
        }
        return smoothstep(f / peak)
    }

    public static func stops(count: Int = 24) -> [Stop] {
        precondition(count > 1, "a crest needs at least two stops")
        return (0...count).map { step in
            let location = Double(step) / Double(count)
            return Stop(location: location, opacity: profile(atFraction: location) * peakOpacity)
        }
    }

    public static func waveStops(wavelengths: Int, samplesEach: Int = 12) -> [Stop] {
        precondition(wavelengths > 0, "a train needs at least one crest")
        precondition(samplesEach > 1, "a crest needs at least two stops")
        let total = wavelengths * samplesEach
        return (0...total).map { step in
            let location = Double(step) / Double(total)
            let within = Double(step % samplesEach) / Double(samplesEach)
            let fraction = step == total ? 0 : within
            return Stop(location: location, opacity: profile(atFraction: fraction) * peakOpacity)
        }
    }

    public static func travel(alongWidth width: Double) -> ClosedRange<Double> {
        let half = length / 2
        return (-half)...(max(width, 0) + half)
    }

    public static func restingCentre(alongWidth width: Double) -> Double {
        let usable = max(width, 0)
        return usable - min(length, usable) / 2
    }

    public static func wavelengths(alongWidth width: Double) -> Int {
        max(2, Int((max(width, 0) / waveLength).rounded(.up)) + 1)
    }

    private static func smoothstep(_ t: Double) -> Double {
        let x = min(max(t, 0), 1)
        return x * x * (3 - 2 * x)
    }
}
