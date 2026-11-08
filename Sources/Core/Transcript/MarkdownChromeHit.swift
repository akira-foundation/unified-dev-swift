import CoreGraphics

public enum MarkdownChromeHit {
    public static func keeps(hitIsHost: Bool, point: CGPoint, controls: CGRect) -> Bool {
        !hitIsHost || controls.contains(point)
    }
}
