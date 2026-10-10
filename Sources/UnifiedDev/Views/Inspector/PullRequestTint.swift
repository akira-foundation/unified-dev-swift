import SwiftUI
import Core

extension PullRequestStanding.Tone {
    var pathColour: Color {
        switch self {
        case .quiet: Palette.textSecondary
        case .accent: Palette.controlAccent
        case .positive: Palette.positive
        case .danger: Palette.negative
        case .warning: Palette.warning
        case .merged: Palette.merged
        }
    }
}

extension PullRequestStatus.Tone {
    var color: Color? {
        switch self {
        case .neutral: nil
        case .positive: Palette.positive
        case .negative: Palette.negative
        case .warning: Palette.warning
        case .merged: Palette.merged
        }
    }
}
