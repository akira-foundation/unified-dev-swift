import SwiftUI
import Core

extension PullRequestStanding.Tone {
    var pathColour: Color {
        switch self {
        case .quiet: Palette.textSecondary
        case .accent: Palette.controlAccent
        case .danger: Palette.negative
        case .warning: Palette.warning
        case .merged: Palette.merged
        }
    }

    var badgeColour: Color {
        self == .quiet ? Palette.textSecondary : pathColour
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

    var fill: Color {
        switch self {
        case .merged: Palette.mergedFill
        default: color ?? Palette.controlAccent
        }
    }

    var symbol: String {
        switch self {
        case .neutral: "circle"
        case .positive: "checkmark.circle"
        case .negative: "xmark.circle"
        case .warning: "exclamationmark.triangle"
        case .merged: "arrow.triangle.merge"
        }
    }
}
