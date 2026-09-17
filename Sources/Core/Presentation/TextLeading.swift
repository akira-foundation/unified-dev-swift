import Foundation

public enum TextLeading {
    public static let proseRatio: Double = ChatLineHeight.defaultChoice.ratio

    public static let codeRatio: Double = 1.3

    public static func overPointSize(
        lineHeight: Double, pointSize: Double, ratio: Double = proseRatio
    ) -> Double {
        guard lineHeight > 0, pointSize > 0 else { return 0 }
        return max(0, (ratio * pointSize - lineHeight).rounded())
    }

    public static func overLineBox(lineHeight: Double, ratio: Double = codeRatio) -> Double {
        guard lineHeight > 0 else { return 0 }
        return max(0, (ratio * lineHeight - lineHeight).rounded())
    }
}
