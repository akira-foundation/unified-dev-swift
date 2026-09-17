import CoreGraphics

public enum SearchPanelLayout {
    public static let minimumWidth: CGFloat = 560

    public static let maximumWidth: CGFloat = 800

    public static let proportion: CGFloat = 0.42

    public static let margin: CGFloat = 80

    public static let topInset: CGFloat = 56

    public static let dimLight: Double = 0.22

    public static let dimDark: Double = 0.40

    public static func dim(isDark: Bool) -> Double {
        isDark ? dimDark : dimLight
    }

    public static func width(inWindow windowWidth: CGFloat) -> CGFloat {
        let wanted = min(max(windowWidth * proportion, minimumWidth), maximumWidth)
        let fits = max(minimumWidth, windowWidth - 2 * margin)
        return min(wanted, fits)
    }
}
