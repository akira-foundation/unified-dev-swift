import SwiftUI
import Core

struct SpendColumnsTable: View {
    let board: SpendBoard

    var body: some View {
        ForEach(board.rankedColumns) { column in
            LabeledContent {
                Text(SpendLines.columnCost(column, in: board.total))
                    .monospacedDigit()
            } label: {
                Label(column.column.label, systemImage: "circle.fill")
                    .labelStyle(SpendDotLabelStyle(ink: SpendColumnInk.of(column.column)))
                Text(SpendLines.columnCaption(column))
            }
        }
        if board.total.hasUnpricedTokens {
            Text(SpendLines.unpricedLine(board.total.unpriced))
                .settingsFootnote()
        }
    }
}

enum SpendColumnInk {
    static func of(_ column: TokenColumn) -> Color {
        Palette.controlAccent.opacity(opacity(of: column))
    }

    static func opacity(of column: TokenColumn) -> Double {
        switch column {
        case .freshInput: 0.3
        case .cacheRead: 0.5
        case .cacheWrite: 0.72
        case .output: 1
        }
    }
}
