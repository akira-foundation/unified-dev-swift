import CoreGraphics

public enum MarkdownChromeHit {
    public static func keeps(hitIsHost: Bool, point: CGPoint, controls: CGRect) -> Bool {
        !hitIsHost || controls.contains(point)
    }

    public static func visibleText(frame: CGRect, scrollBounds: CGRect?) -> CGRect {
        let whole = CGRect(origin: .zero, size: frame.size)
        let visible = scrollBounds.map(whole.intersection) ?? whole
        return visible.offsetBy(dx: frame.minX, dy: frame.minY)
    }
}
