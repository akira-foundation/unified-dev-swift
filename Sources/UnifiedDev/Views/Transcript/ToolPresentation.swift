import SwiftUI
import Core

extension ToolTint {
    var colour: Color {
        switch self {
        case .neutral: Palette.textSecondary
        case .accent: Palette.accent
        case .positive: Palette.positive
        case .negative: Palette.negative
        case .warning: Palette.warning
        }
    }
}
