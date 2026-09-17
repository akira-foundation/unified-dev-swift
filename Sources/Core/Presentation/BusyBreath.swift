import Foundation

public enum BusyBreath {
    public static let inhale = 0.32
    public static let held = 0.10
    public static let exhale = 0.44

    public static var rest: Double { 1 - inhale - held - exhale }

    public static let period: TimeInterval = 3

    public static func value(atPhase phase: Double) -> Double {
        let p = phase - phase.rounded(.down)
        if p < inhale {
            return 1 - pow(max(0, 1 - p / inhale), 2.5)
        }
        if p < inhale + held {
            return 1
        }
        if p < inhale + held + exhale {
            return pow(max(0, 1 - (p - inhale - held) / exhale), 1.55)
        }
        return 0
    }

    public static let restingOpacity = 0.45

    public static func opacity(atPhase phase: Double) -> Double {
        restingOpacity + (1 - restingOpacity) * value(atPhase: phase)
    }

    public static func opacitySamples(count: Int = 48) -> [Double] {
        samples(count: count).map { restingOpacity + (1 - restingOpacity) * $0 }
    }

    public static func samples(count: Int = 48) -> [Double] {
        precondition(count > 1, "a breath needs at least two samples")
        return (0...count).map { value(atPhase: Double($0) / Double(count)) }
    }
}
