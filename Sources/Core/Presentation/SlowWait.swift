import Foundation

public enum SlowWait {
    public static let threshold: Duration = .milliseconds(500)

    public static func isShowing(
        waited: Duration, isOver: Bool = false, threshold: Duration = threshold
    ) -> Bool {
        !isOver && waited >= threshold
    }

    public static func quiet(
        after waited: Duration = .zero, threshold: Duration = threshold
    ) -> Duration? {
        waited < threshold ? threshold - waited : nil
    }
}
