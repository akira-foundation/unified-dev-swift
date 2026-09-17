import CoreGraphics

public enum ChipRemoveMark {
    public static let glyphScale: CGFloat = 0.58

    public static func glyphPointSize(diameter: CGFloat) -> CGFloat {
        diameter * glyphScale
    }

    public static let emphasisPlate: CGFloat = 0.16

    public static let emphasisPlateHovered: CGFloat = 0.28

    public static let emphasisRing: CGFloat = 0.35
}
