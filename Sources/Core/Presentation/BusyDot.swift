import Foundation

public enum BusyDot {
    public static let period: TimeInterval = 1.5

    public static let peakScale = 1.35

    public static let peakOpacity = 0.5

    public static let resting = 0.0

    public static func scale(at pulse: Double) -> Double {
        interpolated(from: 1, to: peakScale, at: pulse)
    }

    public static func opacity(at pulse: Double) -> Double {
        interpolated(from: 1, to: peakOpacity, at: pulse)
    }

    public static var drawnScale: Double { peakScale }

    public static func pathScale(at pulse: Double) -> Double {
        scale(at: pulse) / drawnScale
    }

    private static func interpolated(from: Double, to: Double, at fraction: Double) -> Double {
        from + (to - from) * min(max(fraction, 0), 1)
    }
}
