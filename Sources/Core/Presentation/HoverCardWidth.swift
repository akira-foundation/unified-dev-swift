import CoreGraphics

public enum HoverCardWidth {
    public static let minimum: CGFloat = 320

    public static let ceiling: CGFloat = 520

    public static func fits(content: CGFloat) -> CGFloat {
        guard content.isFinite else { return minimum }
        return min(max(content.rounded(.up), minimum), ceiling)
    }
}
