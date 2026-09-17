import Foundation

public enum TranscriptTextMeasure {
    public static func bubbleTextOffset(height: Double, inkTop: Double, inkBottom: Double) -> Double {
        guard height.isFinite, inkTop.isFinite, inkBottom.isFinite,
              inkTop >= 0, inkBottom > inkTop, inkBottom <= height else { return 0 }
        return (height - inkBottom - inkTop) / 2
    }

    public static let idealWidth: Double = 100_000

    public static let floorWidth: Double = 1

    public struct Size: Equatable, Sendable {
        public var width: Double
        public var height: Double

        public init(width: Double, height: Double) {
            self.width = width
            self.height = height
        }
    }

    public static func layoutWidth(proposed: Double?) -> Double {
        guard let proposed, proposed.isFinite else { return idealWidth }
        return max(proposed, floorWidth)
    }

    public static func size(
        widestLine: Double,
        usedHeight: Double,
        proposed: Double?,
        lineHeight: Double,
        hasGlyphs: Bool
    ) -> Size {
        guard hasGlyphs else { return Size(width: 0, height: 0) }

        var width = widestLine.rounded(.up)
        if let proposed, proposed.isFinite, proposed > 0 {
            width = min(width, proposed)
        }
        if !(width > 0) { width = room(offered: proposed) }

        var height = usedHeight.rounded(.up)
        if !(height > 0) { height = max(lineHeight.rounded(.up), floorWidth) }

        return Size(width: width, height: height)
    }

    private static func room(offered proposed: Double?) -> Double {
        guard let proposed, proposed.isFinite, proposed > 0 else { return floorWidth }
        return proposed
    }
}
