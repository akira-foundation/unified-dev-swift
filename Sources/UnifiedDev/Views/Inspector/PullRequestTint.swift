import SwiftUI
import Core

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
