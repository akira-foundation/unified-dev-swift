import Foundation

public struct AccentInk: Sendable, Hashable {
    public static let achromaticChroma = 10.0
    public static let enhancedTextFloor = 7.0
    public static let collisionDistance = 12.0

    private static let grounds = [PaletteInk.surface, PaletteInk.surfaceRaised, PaletteInk.surfaceSunken]
    private static let mixSteps = 50

    public let accent: UInt32
    public let isDark: Bool

    public init(accent: UInt32, isDark: Bool) {
        self.accent = accent
        self.isDark = isDark
    }

    public init(red: Double, green: Double, blue: Double, isDark: Bool) {
        let accent = [red, green, blue].reduce(UInt32(0)) { packed, component in
            (packed << 8) | UInt32((min(max(component, 0), 1) * 255).rounded())
        }
        self.init(accent: accent, isDark: isDark)
    }

    public var fill: UInt32 { accent }

    public var isAchromatic: Bool {
        let lab = Contrast.lab(of: accent)
        return (lab.a * lab.a + lab.b * lab.b).squareRoot() < Self.achromaticChroma
    }

    public var textFloor: Double {
        isAchromatic ? Self.enhancedTextFloor : Contrast.textFloor
    }

    public var ink: UInt32 {
        let grounds = Self.grounds.map { $0.member(dark: isDark) }
        let toward: UInt32 = isDark ? 0xFFFFFF : 0x000000
        for step in 0...Self.mixSteps {
            let share = Double(step) / Double(Self.mixSteps)
            let candidate = Contrast.composited(toward, over: accent, at: share)
            if grounds.allSatisfy({ Contrast.ratio(candidate, $0) >= textFloor }) {
                return candidate
            }
        }
        return toward
    }

    public var onFill: UInt32 {
        let white: UInt32 = 0xFFFFFF
        let black: UInt32 = 0x000000
        let onWhite = Contrast.ratio(white, fill)
        if isAchromatic {
            return onWhite >= Contrast.ratio(black, fill) ? white : black
        }
        return onWhite >= Contrast.largeTextFloor ? white : black
    }

    public func collides(with meaning: PaletteMeaning) -> Bool {
        Contrast.deltaE(accent, meaning.ink.member(dark: isDark)) < Self.collisionDistance
    }

    public func stepsAside(beside meanings: [PaletteMeaning]) -> Bool {
        meanings.contains(where: collides(with:))
    }
}
