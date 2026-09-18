import Foundation
import SwiftUI

enum TranscriptLayout {
    static let tight = Metrics.spacingTight

    static let waitingOpacity = 0.55
    static let inset = Metrics.spacing
    static let block = Metrics.spacingWide

    static let cardInset = Metrics.gutter

    static let optionTextIndent = Metrics.spacingWide + glyphWidth + glyphGap

    static let turnGap: CGFloat = block * 2

    static let topSpace: CGFloat = block * 3

    static let rowHeight: CGFloat = 24

    static let glyphWidth: CGFloat = 16
    static let glyphGap: CGFloat = 8
    static let labelCeiling: CGFloat = 176
    static let detailIndent: CGFloat = glyphWidth + glyphGap + inset
    static let nestIndent: CGFloat = 16
    static let rule: CGFloat = 2
    static let disclosureWidth: CGFloat = 14
    static let chipInset = Metrics.chipInsetH

    static let proseMeasure: CGFloat = 680

    static let conversationMeasure: CGFloat = 760
}
