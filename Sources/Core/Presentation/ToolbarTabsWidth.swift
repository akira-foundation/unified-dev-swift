import CoreGraphics

public enum ToolbarTabsWidth {
    public static let minimum: CGFloat = 240

    public static let reservedForActions: CGFloat = 170

    public static func width(inColumn column: CGFloat) -> CGFloat {
        max(minimum, column - reservedForActions)
    }

    public static func showsStrip(tabCount: Int) -> Bool {
        tabCount > 1
    }
}
