import Foundation

struct TranscriptGeometry: Equatable {
    var paneHeight: CGFloat = 0
    var isNearBottom = true
    var isFarFromEnd = false

    static let step: CGFloat = 8

    static let reachStep: Double = 200

    static let heightStep: CGFloat = 32

    static func cap(width: CGFloat, share: CGFloat, gutter: CGFloat, floor: CGFloat) -> CGFloat {
        let raw = max(floor, (width - gutter * 2) * share)
        return (raw / step).rounded(.down) * step
    }

    static func height(_ height: CGFloat) -> CGFloat {
        guard height > 0 else { return 0 }
        return max(heightStep, (height / heightStep).rounded(.down) * heightStep)
    }

    static func reach(contentHeight: Double, viewportHeight: Double, offset: Double) -> Double {
        let raw = max(0, contentHeight - offset - viewportHeight)
        return (raw / reachStep).rounded(.down) * reachStep
    }
}
