import Foundation

public enum PaletteInk {
    public struct Pair: Sendable, Hashable {
        public let light: UInt32
        public let dark: UInt32

        public init(light: UInt32, dark: UInt32) {
            self.light = light
            self.dark = dark
        }

        public func member(dark isDark: Bool) -> UInt32 { isDark ? dark : light }
    }

    public static let windowBackground = Pair(light: 0xFFFFFF, dark: 0x1E1E1E)
    public static let surface = Pair(light: 0xFFFFFF, dark: 0x1E1E1E)
    public static let surfaceRaised = Pair(light: 0xFFFFFF, dark: 0x1E1E1E)
    public static let surfaceSunken = Pair(light: 0xFFFFFF, dark: 0x1E1E1E)
    public static let selected = Pair(light: 0xDCDCDC, dark: 0x464646)
    public static let border = Pair(light: 0xE6E6E6, dark: 0x343434)
    public static let textTertiary = Pair(light: 0xBDBDBD, dark: 0x565656)
    public static let multicolorAccent = Pair(light: 0x7C3AED, dark: 0x8456EF)
    public static let negative = Pair(light: 0xFF383C, dark: 0xFF4245)
    public static let stop = Pair(light: 0xFF5659, dark: 0xDD3D3F)
    public static let warning = Pair(light: 0xFF8D28, dark: 0xFF9230)
    public static let running = Pair(light: 0x7C3AED, dark: 0x8B5CF6)
    public static let merged = Pair(light: 0xCB30E0, dark: 0xDB34F2)
    public static let mergedFill = Pair(light: 0x9A1FAC, dark: 0x9A1FAC)
    public static let workspaceMessage = Pair(light: 0x4F5BD5, dark: 0x8E9BFF)
    public static let workspaceMessageFill = Pair(light: 0xE6E8FB, dark: 0x2A3470)
    public static let diffPositive = Pair(light: 0x28CD41, dark: 0x30D158)
    public static let positive = Pair(light: 0x34C759, dark: 0x30D158)
    public static let synKeyword = Pair(light: 0x9B2393, dark: 0xD08EE0)
    public static let synType = Pair(light: 0x0B7285, dark: 0x5BC8DB)
    public static let synString = Pair(light: 0xC0392B, dark: 0xE8846E)
    public static let synNumber = Pair(light: 0x1C6FBB, dark: 0x7FB3F0)
    public static let synComment = Pair(light: 0x6D7879, dark: 0x8B8B93)
    public static let synFunction = Pair(light: 0x2F5FD0, dark: 0x89AFF5)
    public static let synVariable = Pair(light: 0x6A3FB5, dark: 0xB49BF0)
    public static let synAttribute = Pair(light: 0x8A6A00, dark: 0xD9B65C)
    public static let synOperator = Pair(light: 0x5A5A60, dark: 0xA8A8B0)

    public static let accentTextSelection = Pair(light: 0xBAD6DF, dark: 0x46626B)

    public static let selectedTextInk = Pair(light: 0x000000, dark: 0xFFFFFF)
}
