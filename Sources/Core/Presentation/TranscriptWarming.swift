import Foundation

public enum TranscriptWarming {
    public static let ceiling: Double = 2_048

    public static let mostRows = 60

    public static func reach(viewport: Double) -> Double {
        guard viewport > 0 else { return 0 }
        return min(viewport * 2, ceiling)
    }

    public static func worthWarming(_ band: Range<Int>, most: Int = mostRows) -> Range<Int> {
        guard most > 0 else { return band.upperBound..<band.upperBound }
        guard band.count > most else { return band }
        return (band.upperBound - most)..<band.upperBound
    }
}
