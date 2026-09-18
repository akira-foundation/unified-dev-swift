import Foundation

public enum PaletteMeaning: CaseIterable, Sendable {
    case warning
    case negative
    case positive
    case running
    case merged

    public var ink: PaletteInk.Pair {
        switch self {
        case .warning: PaletteInk.warning
        case .negative: PaletteInk.negative
        case .positive: PaletteInk.positive
        case .running: PaletteInk.running
        case .merged: PaletteInk.merged
        }
    }
}
