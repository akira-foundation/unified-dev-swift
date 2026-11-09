import CoreGraphics

public enum FullScreenToolbarGround {
    public static func correctedHeight(
        current: CGFloat,
        toolbarBand: CGFloat,
        screenTopInset: CGFloat
    ) -> CGFloat? {
        guard screenTopInset > 0, toolbarBand > 0, current > toolbarBand + 0.5 else { return nil }
        return toolbarBand
    }
}
