import CoreGraphics

public enum WelcomeSheetFit {
    public static let shortestLaptopVisibleHeight: CGFloat = 867
    public static let titleBarHeight: CGFloat = 32
    public static let screenMargin: CGFloat = 24

    public static let defaultHeightLimit: CGFloat =
        shortestLaptopVisibleHeight - titleBarHeight - screenMargin * 2

    public static func heightLimit(forVisibleHeight visible: CGFloat?) -> CGFloat {
        let available = visible.map { min($0, shortestLaptopVisibleHeight) }
            ?? shortestLaptopVisibleHeight
        return available - titleBarHeight - screenMargin * 2
    }
}
