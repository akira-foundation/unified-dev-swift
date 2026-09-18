import CoreGraphics

extension SplitPaneFrame {
    public static let underBarReach: CGFloat = 200

    public var touchesTop: Bool { frame.minY < 1 }

    public func clip(of bounds: CGRect) -> CGRect {
        guard touchesTop else { return bounds }
        return CGRect(
            x: bounds.minX,
            y: bounds.minY - Self.underBarReach,
            width: bounds.width,
            height: bounds.height + Self.underBarReach
        )
    }
}
