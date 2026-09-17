import Foundation

public enum BusyRule {
    public static let restingOpacity = 0.32

    public static let peakOpacity = 1.0

    public static var period: TimeInterval { BusyDot.period }

    public static let resting = 0.0

    public static func opacity(at pulse: Double) -> Double {
        let fraction = min(max(pulse, 0), 1)
        return restingOpacity + (peakOpacity - restingOpacity) * fraction
    }

    public static let restingHeight = 1.0

    public static let peakHeight = 3.0

    public static func height(at pulse: Double) -> Double {
        let fraction = min(max(pulse, 0), 1)
        return restingHeight + (peakHeight - restingHeight) * fraction
    }
}
