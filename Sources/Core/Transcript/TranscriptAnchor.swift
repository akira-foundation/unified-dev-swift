import Foundation

public enum TranscriptAnchor {
    public static func delta(rowTop: Double, viewportTop: Double) -> Double {
        rowTop - viewportTop
    }

    public static func offset(rowTop: Double, delta: Double) -> Double {
        rowTop - delta
    }

    public static func end(contentHeight: Double, viewportHeight: Double) -> Double {
        max(0, contentHeight - viewportHeight)
    }

    public static let laidOut: Double = 1

    public static func canPlace(viewportHeight: Double) -> Bool {
        viewportHeight > laidOut
    }

    public static func clamped(
        _ offset: Double, contentHeight: Double, viewportHeight: Double
    ) -> Double {
        min(max(0, offset), end(contentHeight: contentHeight, viewportHeight: viewportHeight))
    }

    public static func offset(
        rowTop: Double, rowHeight: Double, viewportHeight: Double, anchor: Double
    ) -> Double {
        rowTop + rowHeight * anchor - viewportHeight * anchor
    }

    public enum Place: Equatable, Sendable {
        case end
        case anchor
        case stay
    }

    public static func place(
        holdsEnd: Bool, wasAtEnd: Bool, followerDriving: Bool, hasAnchor: Bool
    ) -> Place {
        if holdsEnd || (wasAtEnd && !followerDriving) { return .end }
        return hasAnchor ? .anchor : .stay
    }

    public static func isAtEnd(
        offset: Double, contentHeight: Double, viewportHeight: Double
    ) -> Bool {
        end(contentHeight: contentHeight, viewportHeight: viewportHeight) - offset <= 1
    }
}
