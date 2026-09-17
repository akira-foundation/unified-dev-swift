import Foundation

public enum ListLeading {
    public static func betweenProseItems(
        tight: Bool, lineHeight: Double, pointSize: Double, ratio: Double
    ) -> Double {
        let leading = TextLeading.overPointSize(
            lineHeight: lineHeight, pointSize: pointSize, ratio: ratio
        )
        let separation = (pointSize * 0.2).rounded()
        return leading * (tight ? 1 : 2) + separation
    }

    public static func betweenItems(
        tight: Bool, lineHeight: Double, pointSize: Double, ratio: Double
    ) -> Double {
        let leading = TextLeading.overPointSize(
            lineHeight: lineHeight, pointSize: pointSize, ratio: ratio
        )
        return tight ? leading : leading * 2
    }
}
