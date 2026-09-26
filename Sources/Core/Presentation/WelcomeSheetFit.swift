import CoreGraphics

public enum WelcomeSheetFit {
    public static let shortestLaptopVisibleHeight: CGFloat = 867
    public static let titleBarHeight: CGFloat = 32
    public static let screenMargin: CGFloat = 24

    public static let heightLimit: CGFloat =
        shortestLaptopVisibleHeight - titleBarHeight - screenMargin * 2
}
