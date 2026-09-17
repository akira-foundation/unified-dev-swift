import CoreGraphics
import Foundation

public struct InspectorSlide: Equatable, Sendable {
    public let from: CGFloat

    public let to: CGFloat

    public let seconds: TimeInterval

    public init(from: CGFloat, to: CGFloat, seconds: TimeInterval) {
        self.from = from
        self.to = to
        self.seconds = seconds
    }

    public func width(after elapsed: TimeInterval) -> CGFloat {
        guard seconds > 0, elapsed > 0 else { return elapsed > 0 ? to : from }
        guard elapsed < seconds else { return to }
        return from + (to - from) * CGFloat(Self.ease(elapsed / seconds))
    }

    public func hasFinished(after elapsed: TimeInterval) -> Bool {
        guard seconds > 0 else { return true }
        return !(elapsed < seconds)
    }

    public static func ease(_ fraction: Double) -> Double {
        guard fraction > 0 else { return 0 }
        guard fraction < 1 else { return 1 }

        var t = fraction
        for _ in 0..<8 {
            let error = sampleX(t) - fraction
            if abs(error) < tolerance { return sampleY(t) }
            let slope = derivativeX(t)
            if abs(slope) < tolerance { break }
            t -= error / slope
        }

        var low = 0.0
        var high = 1.0
        t = fraction
        for _ in 0..<32 {
            let value = sampleX(t)
            if abs(value - fraction) < tolerance { break }
            if value < fraction { low = t } else { high = t }
            t = (low + high) / 2
        }
        return sampleY(t)
    }

    private static let tolerance = 1e-6

    private static let firstX = 0.42
    private static let secondX = 0.58

    private static var coefficientC: Double { 3 * firstX }
    private static var coefficientB: Double { 3 * (secondX - firstX) - coefficientC }
    private static var coefficientA: Double { 1 - coefficientC - coefficientB }

    private static func sampleX(_ t: Double) -> Double {
        ((coefficientA * t + coefficientB) * t + coefficientC) * t
    }

    private static func derivativeX(_ t: Double) -> Double {
        (3 * coefficientA * t + 2 * coefficientB) * t + coefficientC
    }

    private static func sampleY(_ t: Double) -> Double {
        t * t * (3 - 2 * t)
    }
}
