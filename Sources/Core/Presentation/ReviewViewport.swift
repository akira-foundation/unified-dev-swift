import Foundation

public enum ReviewViewport {
    public static func isNear(top: Double, bottom: Double, visibleTop: Double, visibleHeight: Double) -> Bool {
        bottom > visibleTop - visibleHeight / 2 && top < visibleTop + visibleHeight * 1.5
    }

    public static func publishedTop(visibleTop: Double, visibleHeight: Double) -> Double {
        guard visibleHeight > 0 else { return visibleTop }
        let step = visibleHeight / 4
        return (visibleTop / step).rounded() * step
    }
}
