import Foundation

public enum TranscriptPaneHold {
    public static let reflowStep: Double = 8

    public static func reflowsNow(from reflowed: Double, to width: Double) -> Bool {
        abs(width - reflowed) >= reflowStep
    }

    public static let settle: Duration = .milliseconds(150)

    public static let arrival: Duration = .seconds(1)

    public static let margin = 120

    public static func eager(visible: Range<Int>, count: Int) -> Range<Int> {
        guard count > 0, !visible.isEmpty else { return 0..<0 }
        let reach = min(visible.count, margin)
        let lower = max(0, visible.lowerBound - reach)
        let upper = min(count, visible.upperBound + reach)
        guard lower < upper else { return 0..<0 }
        return lower..<upper
    }
}
