import AppKit
import Core

enum MarkdownTextBlocks {
    static let codeHeader = MarkdownMetrics.iconButton + 2 * Metrics.spacing

    static func quote() -> NSTextBlock {
        box(leading: TranscriptLayout.rule + TranscriptLayout.block)
    }

    static func code(footer: CGFloat, margin: CGFloat) -> NSTextBlock {
        let block = box(leading: MarkdownMetrics.blockGap, margin: margin)
        block.setWidth(MarkdownMetrics.blockGap, type: .absoluteValueType, for: .padding, edge: .maxX)
        block.setWidth(codeHeader + MarkdownMetrics.blockGap, type: .absoluteValueType, for: .padding, edge: .minY)
        block.setWidth(MarkdownMetrics.blockGap + footer, type: .absoluteValueType, for: .padding, edge: .maxY)
        return block
    }

    static func table(columns: Int, margin: CGFloat) -> NSTextTable {
        let table = NSTextTable()
        table.numberOfColumns = columns
        table.layoutAlgorithm = .fixedLayoutAlgorithm
        table.setContentWidth(100, type: .percentageValueType)
        table.hidesEmptyCells = false
        if margin > 0 { table.setWidth(margin, type: .absoluteValueType, for: .margin, edge: .minX) }
        return table
    }

    static func cell(_ cell: MarkdownCell, in table: NSTextTable) -> NSTextTableBlock {
        let block = NSTextTableBlock(
            table: table, startingRow: cell.row, rowSpan: 1, startingColumn: cell.column, columnSpan: 1
        )
        block.setContentWidth(100 / CGFloat(max(cell.columns, 1)), type: .percentageValueType)
        block.setWidth(Metrics.spacingWide, type: .absoluteValueType, for: .padding, edge: .minX)
        block.setWidth(Metrics.spacingWide, type: .absoluteValueType, for: .padding, edge: .maxX)
        block.setWidth(Metrics.spacing, type: .absoluteValueType, for: .padding, edge: .minY)
        block.setWidth(Metrics.spacing, type: .absoluteValueType, for: .padding, edge: .maxY)
        if cell.column < cell.columns - 1 {
            block.setWidth(Metrics.outline, type: .absoluteValueType, for: .border, edge: .maxX)
        }
        if cell.row < cell.rows - 1 {
            block.setWidth(Metrics.outline, type: .absoluteValueType, for: .border, edge: .maxY)
        }
        block.setBorderColor(.separatorColor)
        return block
    }

    private static func box(leading: CGFloat, margin: CGFloat = 0) -> NSTextTableBlock {
        let block = NSTextTableBlock(
            table: table(columns: 1, margin: margin), startingRow: 0, rowSpan: 1, startingColumn: 0, columnSpan: 1
        )
        block.setContentWidth(100, type: .percentageValueType)
        block.setWidth(leading, type: .absoluteValueType, for: .padding, edge: .minX)
        return block
    }
}
