import AppKit
import Core
import SwiftUI

@MainActor
struct MarkdownTextBuilder {
    static let lineCap = 2_000
    static let foldHeight: CGFloat = 28

    let style: MarkdownTextStyle
    let isStreaming: Bool
    let expanded: Set<Int>
    let footers: [Int: CGFloat]

    private var output = NSMutableAttributedString()
    private var rootStarts: [Int: Int] = [:]
    private var code: [MarkdownCodeSpec] = []
    private var quotes: [MarkdownQuoteSpec] = []
    private var tables: [MarkdownTableSpec] = []
    private var rules: [NSRange] = []
    private var quoteBlocks: [Int: NSTextBlock] = [:]
    private var quoteOrder: [Int: Int] = [:]
    private var tableBlocks: [Int: NSTextTable] = [:]
    private var separatorAttributes: [NSAttributedString.Key: Any] = [:]
    private var lastLeading: CGFloat = 0
    private var keptLength = 0

    init(style: MarkdownTextStyle, isStreaming: Bool, expanded: Set<Int>, footers: [Int: CGFloat]) {
        self.style = style
        self.isStreaming = isStreaming
        self.expanded = expanded
        self.footers = footers
    }

    mutating func build(_ blocks: [MarkdownBlock], continuing previous: MarkdownText?) -> MarkdownText {
        let pieces = MarkdownPieces.flatten(blocks)
        var start = 0
        if let previous, isStreaming {
            start = keep(from: previous, pieces: pieces)
        }
        for index in start..<pieces.count {
            let piece = pieces[index]
            if rootStarts[piece.root] == nil { rootStarts[piece.root] = output.length }
            append(piece, at: index)
        }
        let text = MarkdownText(
            attributed: output, style: style, isStreamingText: isStreaming, pieces: pieces, rootStarts: rootStarts, code: code,
            quotes: quotes, tables: tables, rules: rules
        )
        if start > 0 {
            text.source = previous
            text.keptLength = keptLength
        }
        return text
    }

    private mutating func keep(from previous: MarkdownText, pieces: [MarkdownPiece]) -> Int {
        guard let prefix = previous.keptPrefix(for: pieces) else { return 0 }
        let kept = prefix.pieces, boundary = prefix.boundary, length = prefix.length
        keptLength = length
        output = NSMutableAttributedString(
            attributedString: previous.attributed.attributedSubstring(from: NSRange(location: 0, length: length))
        )
        rootStarts = previous.rootStarts.filter { $0.key < boundary }
        code = previous.code.filter { $0.piece < kept }
        let end = output.length
        quotes = previous.quotes.filter { NSMaxRange($0.range) <= end }
        tables = previous.tables.filter { $0.last.location < end }
        rules = previous.rules.filter { NSMaxRange($0) <= end }
        separatorAttributes = output.attributes(at: end - 1, effectiveRange: nil)
        separatorAttributes[.markdownPiece] = nil
        separatorAttributes[.markdownMarker] = nil
        separatorAttributes[.link] = nil
        separatorAttributes[.attachment] = nil
        lastLeading = (separatorAttributes[.paragraphStyle] as? NSParagraphStyle)?.lineSpacing ?? 0
        return kept
    }

    private mutating func append(_ piece: MarkdownPiece, at index: Int) {
        if output.length > 0 {
            output.append(NSAttributedString(string: "\n", attributes: separatorAttributes))
        }
        let containers = containers(for: piece)
        appendSpacer(gap(piece.gap), containers: piece.quotes.filter { quoteOrder[$0] != nil }.compactMap { quoteBlocks[$0] })
        let start = output.length
        switch piece.body {
        case let .text(inline, heading):
            appendText(inline, heading: heading, piece: piece, index: index, containers: containers)
        case let .code(source, language, info):
            appendCode(source, language: language, info: info, piece: piece, index: index, containers: containers)
        case let .cell(cell):
            appendCell(cell, piece: piece, index: index, containers: containers)
        case .rule:
            appendRule(index: index, containers: containers)
        }
        for id in piece.quotes {
            guard let block = quoteBlocks[id] else { continue }
            let range = NSRange(location: start, length: output.length - start)
            if let order = quoteOrder[id] {
                let current = quotes[order].range
                quotes[order].range = NSUnionRange(current, range)
            } else {
                quoteOrder[id] = quotes.count
                quotes.append(MarkdownQuoteSpec(block: block, range: range))
            }
        }
    }

    private func gap(_ gap: MarkdownPiece.Gap) -> CGFloat {
        max(0, style.points(for: gap) - lastLeading)
    }

    private mutating func containers(for piece: MarkdownPiece) -> [NSTextBlock] {
        piece.quotes.map { id in
            if let held = quoteBlocks[id] { return held }
            let block = MarkdownTextBlocks.quote()
            quoteBlocks[id] = block
            return block
        }
    }

    private mutating func appendSpacer(_ height: CGFloat, containers: [NSTextBlock]) {
        guard height > 0, output.length > 0 else { return }
        let paragraph = NSMutableParagraphStyle()
        paragraph.minimumLineHeight = height
        paragraph.maximumLineHeight = height
        paragraph.textBlocks = containers
        output.append(NSAttributedString(string: "\n", attributes: [
            .font: NSFont.systemFont(ofSize: 1), .paragraphStyle: paragraph,
        ]))
    }

    private mutating func appendText(
        _ inline: [MarkdownInline], heading: Int?, piece: MarkdownPiece, index: Int, containers: [NSTextBlock]
    ) {
        let rung = heading.map(Self.headingFont) ?? Typo.body
        let paragraph = style.paragraph(for: piece, containers: containers)
        let color: NSColor = piece.quotes.isEmpty ? .labelColor : .secondaryLabelColor
        let font = rung.resolvedNSFont(scale: style.scale, face: style.face)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font, .foregroundColor: color, .paragraphStyle: paragraph, .markdownPiece: index,
        ]
        if let marker = piece.marker {
            output.append(MarkdownTextMarker.make(marker, font: font, body: Typo.body.resolvedNSFont(scale: style.scale, face: style.face), attributes: attributes))
        }
        let body = InlineNSAttributes.rendered(
            inline, font: font,
            code: rung.monospacedCompanionNSFont(scale: style.scale, face: style.face),
            color: color, addsSourceIcons: !isStreaming
        )
        MarkdownTextStyle.softenBreaks(in: body)
        let range = NSRange(location: 0, length: body.length)
        body.addAttribute(.paragraphStyle, value: paragraph, range: range)
        body.addAttribute(.markdownPiece, value: index, range: range)
        output.append(body)
        remember(attributes)
    }

    private mutating func appendCode(
        _ source: String, language: Language, info: String, piece: MarkdownPiece, index: Int, containers: [NSTextBlock]
    ) {
        let ordinal = code.count
        let prepared = CodeBlockPreparationCache.prepared(code: source, language: language, isStreaming: isStreaming)
        let folds = prepared.lines.count > Self.lineCap
        let showsAll = expanded.contains(ordinal)
        let visible = showsAll ? prepared.lines.count : min(prepared.lines.count, Self.lineCap)
        let footer = footers[ordinal] ?? (folds ? Self.foldHeight : 0)

        let block = MarkdownTextBlocks.code(footer: footer, margin: style.indent(of: piece).head)

        let font = Typo.code.resolvedNSFont(scale: style.scale, face: style.face)
        let paragraph = style.boxed(containers + [block])
        let body = NSMutableAttributedString()
        for offset in 0..<visible {
            if offset > 0 { body.append(NSAttributedString(string: "\n")) }
            body.append(SyntaxCache.attributedNS(
                line: prepared.lines[offset], language: language, carry: prepared.carries[offset]
            ))
        }
        if body.length == 0 { body.append(NSAttributedString(string: " ")) }
        let range = NSRange(location: 0, length: body.length)
        body.addAttributes([.font: font, .paragraphStyle: paragraph, .markdownPiece: index], range: range)
        let start = output.length
        output.append(body)
        code.append(MarkdownCodeSpec(
            index: ordinal, piece: index, block: block,
            range: NSRange(location: start, length: body.length),
            code: source, language: language, info: info,
            lines: prepared.lines.count, isFolded: folds, visibleAll: showsAll, footer: footer
        ))
        remember([.font: font, .foregroundColor: NSColor.labelColor, .paragraphStyle: paragraph])
    }

    private mutating func appendCell(_ cell: MarkdownCell, piece: MarkdownPiece, index: Int, containers: [NSTextBlock]) {
        let table = tableBlocks[cell.table] ?? MarkdownTextBlocks.table(columns: cell.columns, margin: style.indent(of: piece).head)
        tableBlocks[cell.table] = table
        let block = MarkdownTextBlocks.cell(cell, in: table)

        let rung = cell.row == 0 ? Typo.labelEmphasis : Typo.label
        let font = rung.resolvedNSFont(scale: style.scale, face: style.face)
        let paragraph = style.boxed(containers + [block])
        paragraph.alignment = switch cell.alignment {
        case .leading: .left
        case .center: .center
        case .trailing: .right
        }
        let color: NSColor = piece.quotes.isEmpty ? .labelColor : .secondaryLabelColor
        let body = InlineNSAttributes.rendered(
            cell.inline, font: font,
            code: rung.monospacedCompanionNSFont(scale: style.scale, face: style.face),
            color: color, addsSourceIcons: !isStreaming
        )
        MarkdownTextStyle.softenBreaks(in: body)
        let range = NSRange(location: 0, length: body.length)
        body.addAttribute(.paragraphStyle, value: paragraph, range: range)
        body.addAttribute(.markdownPiece, value: index, range: range)
        let start = output.length
        output.append(body)
        let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color, .paragraphStyle: paragraph]
        if body.length == 0 {
            var placeholder = attributes
            placeholder[.markdownPiece] = index
            placeholder[.markdownMarker] = true
            output.append(NSAttributedString(string: "\u{200B}", attributes: placeholder))
        }
        remember(attributes)
        trackTable(cell, block: block, start: start)
    }

    private mutating func trackTable(_ cell: MarkdownCell, block: NSTextTableBlock, start: Int) {
        let located = MarkdownCellSpec(block: block, location: start)
        if cell.row == 0, cell.column == 0 {
            tables.append(MarkdownTableSpec(first: located, firstRowLast: located, last: located))
            return
        }
        guard let index = tables.indices.last else { return }
        tables[index].last = located
        if cell.row == 0 { tables[index].firstRowLast = located }
    }

    private mutating func appendRule(index: Int, containers: [NSTextBlock]) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.minimumLineHeight = max(Metrics.outline, 1)
        paragraph.maximumLineHeight = max(Metrics.outline, 1)
        paragraph.textBlocks = containers
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 1), .paragraphStyle: paragraph, .markdownPiece: index,
        ]
        rules.append(NSRange(location: output.length, length: 1))
        output.append(NSAttributedString(string: "\u{00A0}", attributes: attributes))
        var ending = attributes
        ending[.markdownPiece] = nil
        remember(ending)
    }

    private mutating func remember(_ attributes: [NSAttributedString.Key: Any]) {
        var ending = attributes
        ending[.markdownPiece] = nil
        separatorAttributes = ending
        lastLeading = (attributes[.paragraphStyle] as? NSParagraphStyle)?.lineSpacing ?? 0
    }

    private static func headingFont(_ level: Int) -> ScaledFont {
        switch level {
        case 1: Typo.heading
        case 2: Typo.title
        default: Typo.bodyEmphasis
        }
    }
}
