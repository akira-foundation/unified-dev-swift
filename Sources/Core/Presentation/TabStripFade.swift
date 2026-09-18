import CoreGraphics

public enum TabStripFade {
    public static let width: CGFloat = 16

    public static func isDrawn(tabsWidth: CGFloat?, stripWidth: CGFloat) -> Bool {
        guard let tabsWidth else { return true }
        return tabsWidth > stripWidth + 1
    }

    public static func step(stripWidth: CGFloat) -> CGFloat {
        guard stripWidth > 0 else { return 0 }
        return min(width / stripWidth, 0.5)
    }
}
