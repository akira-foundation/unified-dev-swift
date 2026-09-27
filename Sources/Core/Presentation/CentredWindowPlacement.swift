import CoreGraphics

public enum CentredWindowPlacement {
    public static func frame(size: CGSize, around anchor: CGRect, visible: CGRect) -> CGRect {
        clamped(CGRect(
            x: anchor.midX - size.width / 2, y: anchor.midY - size.height / 2,
            width: size.width, height: size.height
        ), to: visible)
    }

    public static func frame(size: CGSize, keepingTopOf current: CGRect, visible: CGRect) -> CGRect {
        clamped(CGRect(
            x: current.midX - size.width / 2, y: current.maxY - size.height,
            width: size.width, height: size.height
        ), to: visible)
    }

    private static func clamped(_ frame: CGRect, to visible: CGRect) -> CGRect {
        let x = min(max(frame.minX, visible.minX), max(visible.minX, visible.maxX - frame.width))
        let y = min(max(frame.minY, visible.minY), max(visible.minY, visible.maxY - frame.height))
        return CGRect(origin: CGPoint(x: x, y: y), size: frame.size)
    }
}
