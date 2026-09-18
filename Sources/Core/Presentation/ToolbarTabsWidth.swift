import CoreGraphics

public enum ToolbarTabsWidth {
    public static let minimum: CGFloat = 240

    public static let reservedForActions: CGFloat = 170

    public static func width(inColumn column: CGFloat) -> CGFloat {
        max(minimum, column - reservedForActions)
    }

    public static func showsStrip(tabCount: Int, paneCount: Int = 1, isRenaming: Bool = false) -> Bool {
        guard tabCount > 0 else { return false }
        return tabCount > 1 || paneCount > 1 || isRenaming
    }
}
