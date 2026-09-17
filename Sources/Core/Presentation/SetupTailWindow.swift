import Foundation

public enum SetupTailWindow {
    public static let share = 0.5

    public static let settled = 5

    public static let minimumCap = 3

    public static let maximumCap = 30

    public static let failureFloor = 12

    public static func cap(paneHeight: Double, lineHeight: Double) -> Int {
        guard paneHeight > 0, lineHeight > 0 else { return settled }
        let fits = Int((paneHeight * share / lineHeight).rounded(.down))
        return min(maximumCap, max(minimumCap, fits))
    }

    public static func lines(cap: Int, logLines: Int) -> Int {
        min(cap, max(min(settled, cap), logLines))
    }

    public static func failureLines(cap: Int) -> Int {
        max(failureFloor, cap)
    }
}
