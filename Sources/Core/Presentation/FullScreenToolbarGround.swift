import CoreGraphics

public enum FullScreenToolbarGround {
    public static func applies(isFullScreen: Bool, screenTopInset: CGFloat) -> Bool {
        isFullScreen && screenTopInset > 0
    }

    public static func correctedHeight(current: CGFloat, toolbarBand: CGFloat) -> CGFloat? {
        guard toolbarBand > 0, current > toolbarBand + 0.5 else { return nil }
        return toolbarBand
    }
}
