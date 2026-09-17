import Foundation

public enum TranscriptFollow {
    public static let takeBack: Double = ScrollEnd.threshold * 0.75

    public static let smallestTakeBack: Double = 20

    public static let timeConstant: Double = 0.09

    public static let arrived: Double = 0.5

    public static let smallestStep: Double = 1

    public static let longestFrame: Double = 1.0 / 30

    public static func travels(reduceMotion: Bool) -> Bool {
        !reduceMotion
    }

    public enum Move: Equatable, Sendable {
        case rest
        case settle(Double)
    }

    public static func start(offset: Double, end: Double, grew: Double, ownsGap: Bool) -> Double {
        guard grew > 0, end > 0 else { return offset }
        let gap = end - offset
        guard grew >= smallestTakeBack || gap > arrived else { return offset }
        guard ownsGap || gap <= arrived else { return offset }
        return max(0, end - min(max(gap, grew), takeBack))
    }

    public static func step(offset: Double, end: Double, frame: Double, ownsGap: Bool) -> Move {
        guard end > 0 else { return .rest }
        let gap = end - offset

        guard gap > -arrived else { return .settle(end) }
        guard gap > arrived else { return .rest }
        if gap > ScrollEnd.threshold {
            guard ownsGap else { return .rest }
            return .settle(end - takeBack)
        }

        let elapsed = min(max(frame, 0), longestFrame)
        guard elapsed > 0 else { return .rest }
        let travelled = max(gap * (1 - exp(-elapsed / timeConstant)), min(gap, smallestStep))
        let next = offset + travelled
        return end - next <= arrived ? .settle(end) : .settle(next)
    }
}
