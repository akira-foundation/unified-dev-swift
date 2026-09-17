import Foundation

public enum ScrollEnd {
    public static let threshold: Double = 96

    public static let offerAfterScreens: Double = 1.5

    public static func isWorthOffering(
        contentHeight: Double,
        viewportHeight: Double,
        offset: Double,
        screens: Double = offerAfterScreens
    ) -> Bool {
        guard viewportHeight > 0, contentHeight > viewportHeight else { return false }
        return contentHeight - offset - viewportHeight > viewportHeight * screens
    }

    public static func isAtEnd(
        contentHeight: Double,
        viewportHeight: Double,
        offset: Double,
        threshold: Double = threshold
    ) -> Bool {
        guard viewportHeight > 0 else { return true }
        guard contentHeight > viewportHeight else { return true }
        return contentHeight - offset - viewportHeight < threshold
    }
}
