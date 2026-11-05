import Foundation

public struct MarkdownPiece: Sendable, Hashable {
    public enum Body: Sendable, Hashable {
        case text([MarkdownInline], heading: Int?)
        case code(code: String, language: Language, info: String)
        case cell(MarkdownCell)
        case rule
    }

    public enum Marker: Sendable, Hashable {
        case bullet
        case number(Int)
        case task(checked: Bool)

        public var written: String {
            switch self {
            case .bullet: "\u{2022}"
            case let .number(value): "\(value)."
            case let .task(checked): checked ? "\u{2713}" : "\u{25A1}"
            }
        }
    }

    public enum Gap: Sendable, Hashable {
        case none
        case block
        case heading
        case tightItem
        case looseItem
        case task
    }

    public var body: Body
    public var marker: Marker?
    public var gap: Gap
    public var root: Int
    public var listDepth: Int
    public var isTight: Bool
    public var quotes: [Int]

    public var isTask: Bool {
        if case .task = marker { return true }
        return false
    }
}

public struct MarkdownCell: Sendable, Hashable {
    public var inline: [MarkdownInline]
    public var table: Int
    public var row: Int
    public var column: Int
    public var columns: Int
    public var rows: Int
    public var alignment: TableAlignment
}

public enum MarkdownPieces {
    public static func flatten(_ blocks: [MarkdownBlock]) -> [MarkdownPiece] {
        var writer = Writer()
        for (root, block) in blocks.enumerated() {
            writer.root = root
            writer.write(block, gap: root == 0 ? .none : .block, isFirst: root == 0)
        }
        return writer.pieces
    }

    private struct Context {
        var listDepth = 0
        var isTight = false
        var quotes: [Int] = []
    }

    private struct Writer {
        var pieces: [MarkdownPiece] = []
        var root = 0
        var context = Context()
        var nextGroup = 0
        var marker: MarkdownPiece.Marker?

        mutating func write(_ block: MarkdownBlock, gap: MarkdownPiece.Gap, isFirst: Bool) {
            switch block {
            case let .paragraph(inline):
                add(.text(inline, heading: nil), gap: gap)
            case let .heading(level, inline):
                add(.text(inline, heading: level), gap: isFirst || gap != .block ? gap : .heading)
            case let .codeBlock(code, language, info):
                let settled = settleMarker(gap: gap)
                add(.code(code: code, language: language, info: info), gap: settled ? .block : gap)
            case let .bulletList(items, tight):
                list(items.map { (MarkdownPiece.Marker.bullet, $0) }, tight: tight, gap: gap)
            case let .numberedList(start, items, tight):
                list(items.enumerated().map { (.number(start + $0.offset), $0.element) }, tight: tight, gap: gap)
            case let .taskList(items):
                tasks(items, gap: gap)
            case let .blockQuote(blocks):
                quote(blocks, gap: gap)
            case let .table(headers, rows, alignments):
                table(headers, rows, alignments, gap: gap)
            case .thematicBreak:
                add(.rule, gap: gap)
            }
        }

        private mutating func settleMarker(gap: MarkdownPiece.Gap) -> Bool {
            guard marker != nil else { return false }
            add(.text([], heading: nil), gap: gap)
            return true
        }

        private mutating func add(_ body: MarkdownPiece.Body, gap: MarkdownPiece.Gap) {
            pieces.append(MarkdownPiece(
                body: body,
                marker: marker,
                gap: gap,
                root: root,
                listDepth: context.listDepth,
                isTight: context.isTight,
                quotes: context.quotes
            ))
            marker = nil
        }

        private mutating func stack(_ blocks: [MarkdownBlock], gap: MarkdownPiece.Gap) {
            for (offset, block) in blocks.enumerated() {
                write(block, gap: offset == 0 ? gap : .block, isFirst: offset == 0)
            }
        }

        private mutating func list(
            _ items: [(MarkdownPiece.Marker, [MarkdownBlock])], tight: Bool, gap: MarkdownPiece.Gap
        ) {
            let settled = settleMarker(gap: gap)
            let outer = context
            context.listDepth += 1
            context.isTight = tight
            let between: MarkdownPiece.Gap = tight ? .tightItem : .looseItem
            for (offset, item) in items.enumerated() {
                let itemGap = offset == 0 ? (settled ? .block : gap) : between
                marker = item.0
                if item.1.isEmpty {
                    add(.text([], heading: nil), gap: itemGap)
                } else {
                    stack(item.1, gap: itemGap)
                }
            }
            context = outer
        }

        private mutating func tasks(
            _ items: [(checked: Bool, inline: [MarkdownInline])], gap: MarkdownPiece.Gap
        ) {
            let settled = settleMarker(gap: gap)
            let outer = context
            context.listDepth += 1
            context.isTight = true
            for (offset, item) in items.enumerated() {
                marker = .task(checked: item.checked)
                add(.text(item.inline, heading: nil), gap: offset == 0 ? (settled ? .block : gap) : .task)
            }
            context = outer
        }

        private mutating func quote(_ blocks: [MarkdownBlock], gap: MarkdownPiece.Gap) {
            let outer = context
            context.quotes.append(nextGroup)
            nextGroup += 1
            stack(blocks, gap: gap)
            context = outer
        }

        private mutating func table(
            _ headers: [[MarkdownInline]],
            _ rows: [[[MarkdownInline]]],
            _ alignments: [TableAlignment],
            gap: MarkdownPiece.Gap
        ) {
            let settled = settleMarker(gap: gap)
            let id = nextGroup
            nextGroup += 1
            let all = [headers] + rows
            var first = true
            for (row, cells) in all.enumerated() {
                for column in headers.indices {
                    let cell = MarkdownCell(
                        inline: column < cells.count ? cells[column] : [],
                        table: id,
                        row: row,
                        column: column,
                        columns: headers.count,
                        rows: all.count,
                        alignment: column < alignments.count ? alignments[column] : .leading
                    )
                    add(.cell(cell), gap: first ? (settled ? .block : gap) : .none)
                    first = false
                }
            }
        }
    }
}
