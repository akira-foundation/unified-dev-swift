import SwiftUI
import AppKit
import Core

private final class MarkdownBlockBox: NSObject {
    let blocks: [MarkdownBlock]

    let addresses: [String]

    init(_ blocks: [MarkdownBlock], addresses: [String]) {
        self.blocks = blocks
        self.addresses = addresses
    }

    convenience init(_ blocks: [MarkdownBlock]) {
        self.init(blocks, addresses: LinkPolicy.addresses(in: blocks))
    }
}

private enum MarkdownParseCache {
    nonisolated(unsafe) static let values: NSCache<NSString, MarkdownBlockBox> = {
        let cache = NSCache<NSString, MarkdownBlockBox>()
        cache.countLimit = 0
        cache.totalCostLimit = 8 * 1_024 * 1_024
        return cache
    }()

    static func parsed(for text: String) -> MarkdownBlockBox {
        let key = text as NSString
        if let cached = values.object(forKey: key) { return cached }
        let box = MarkdownBlockBox(MarkdownParser.parse(text))
        values.setObject(box, forKey: key, cost: text.utf8.count)
        return box
    }

    @MainActor private static var streamed: (text: String, box: MarkdownBlockBox)?

    @MainActor static func streamingParsed(for text: String) -> MarkdownBlockBox {
        if let streamed, streamed.text == text { return streamed.box }
        let box = MarkdownBlockBox(MarkdownParser.parse(text), addresses: [])
        streamed = (text, box)
        return box
    }
}

enum MarkdownPrime {
    static func blocks(of text: String) -> [MarkdownBlock] {
        MarkdownParseCache.parsed(for: text).blocks
    }
}

public struct MarkdownView: View {
    private let text: String
    private let isStreaming: Bool

    public init(_ text: String, isStreaming: Bool = false) {
        self.text = text
        self.isStreaming = isStreaming
    }

    public var body: some View {
        let parsed = isStreaming
            ? MarkdownParseCache.streamingParsed(for: text)
            : MarkdownParseCache.parsed(for: text)
        MarkdownBlocksView(blocks: parsed.blocks)
            .environment(\.markdownIsStreaming, isStreaming)
            .opensTranscriptLinks()
            .transcriptLinkMenu(parsed.addresses)
            .transcriptLinkActions(parsed.addresses)
    }
}

extension View {
    func markdownLinkActions(_ actions: TranscriptLinkActions) -> some View {
        environment(\.markdownLinkActions, actions)
    }
}

extension EnvironmentValues {
    @Entry var markdownIsStreaming: Bool = false
    @Entry var markdownLinkActions = TranscriptLinkActions()
    @Entry var markdownLineSpacingOverride: CGFloat?
}

private struct MarkdownBlocksView: View {
    let blocks: [MarkdownBlock]
    var foreground = Palette.textPrimary

    var body: some View {
        VStack(alignment: .leading, spacing: MarkdownMetrics.blockGap) {
            ForEach(blocks.indices, id: \.self) { offset in
                MarkdownBlockView(block: blocks[offset], foreground: foreground, isFirst: offset == 0)
            }
        }
    }
}

private struct MarkdownBlockView: View {
    let block: MarkdownBlock
    let foreground: Color
    var isFirst = false

    @Environment(\.fontScale) private var fontScale
    @Environment(\.chatFont) private var chatFont
    @Environment(\.chatLineHeight) private var chatLineHeight
    @Environment(\.markdownIsStreaming) private var isStreaming
    @Environment(\.markdownLinkActions) private var linkActions
    @Environment(\.markdownLineSpacingOverride) private var lineSpacingOverride

    private var markerWidth: CGFloat { MarkdownMetrics.markerWidth * fontScale }
    private var proseListLineSpacing: CGFloat {
        TranscriptLayout.proseLeading(
            Typo.body, scale: fontScale, face: chatFont, lineHeight: chatLineHeight
        )
    }
    private var listLineSpacing: CGFloat {
        TranscriptLayout.proseLeading(
            Typo.body,
            scale: fontScale,
            face: chatFont,
            ratio: chatLineHeight.listRatio
        )
    }

    private func listItemGap(tight: Bool, prose: Bool = false) -> CGFloat {
        TranscriptLayout.listItemGap(
            Typo.body, scale: fontScale, face: chatFont, lineHeight: chatLineHeight,
            tight: tight, prose: prose
        )
    }

    @ViewBuilder
    var body: some View {
        switch block {
        case let .paragraph(inline):
            inlineText(inline, rung: Typo.body, color: foreground)
        case let .heading(level, inline):
            inlineText(inline, rung: Self.headingFont(level), color: foreground)
                .padding(.top, isFirst ? 0 : MarkdownMetrics.headingLead)
        case let .codeBlock(code, language, _):
            CodeBlockView(code: code, language: language)
        case let .bulletList(items, tight):
            list(items: items, start: nil, tight: tight)
        case let .numberedList(start, items, tight):
            list(items: items, start: start, tight: tight)
        case let .taskList(items):
            taskList(items)
        case let .blockQuote(blocks):
            HStack(alignment: .top, spacing: TranscriptLayout.block) {
                Rectangle()
                    .fill(Palette.border)
                    .frame(width: TranscriptLayout.rule)
                MarkdownBlocksView(blocks: blocks, foreground: Palette.textSecondary)
            }
        case let .table(headers, rows, alignments):
            table(headers: headers, rows: rows, alignments: alignments)
        case .thematicBreak:
            Divider()
        }
    }

    private static func headingFont(_ level: Int) -> ScaledFont {
        switch level {
        case 1: Typo.heading
        case 2: Typo.title
        default: Typo.bodyEmphasis
        }
    }

    @ViewBuilder
    private func inlineText(
        _ inline: [MarkdownInline], rung: ScaledFont, color: Color, spacing: CGFloat? = nil
    ) -> some View {
        let font = rung.resolved(scale: fontScale, face: chatFont)
        if !isStreaming, InlineNSAttributes.hasLink(inline) {
            TranscriptTextView(
                text: InlineNSAttributes.make(
                    inline,
                    font: rung.resolvedNSFont(scale: fontScale, face: chatFont),
                    code: rung.monospacedCompanionNSFont(scale: fontScale, face: chatFont),
                    color: NSColor(color),
                    lineSpacing: spacing ?? lineSpacingOverride ?? TranscriptLayout.proseLeading(
                        Typo.body, scale: fontScale, face: chatFont, lineHeight: chatLineHeight
                    )
                ),
                linkColor: Palette.linkNSColor,
                selectionColor: .selectedTextBackgroundColor,
                actions: linkActions
            )
        } else {
            Text(InlineAttributes.make(
                inline,
                font: font,
                code: rung.monospacedCompanion(scale: fontScale, face: chatFont),
                color: color
            ))
            .font(font)
            .foregroundStyle(color)
            .textSelection(.enabled)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func marker(_ text: String) -> some View {
        Text(text)
            .font(Typo.body)
            .foregroundStyle(Palette.textSecondary)
            .monospacedDigit()
            .frame(width: markerWidth, alignment: .trailing)
    }

    private func list(items: [[MarkdownBlock]], start: Int?, tight: Bool) -> some View {
        VStack(alignment: .leading, spacing: listItemGap(tight: tight, prose: true)) {
            ForEach(items.indices, id: \.self) { offset in
                HStack(alignment: .firstTextBaseline, spacing: Metrics.spacingSmall) {
                    marker(start.map { "\($0 + offset)." } ?? "\u{2022}")
                    MarkdownBlocksView(blocks: items[offset], foreground: foreground)
                        .lineSpacing(proseListLineSpacing)
                        .environment(\.markdownLineSpacingOverride, proseListLineSpacing)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private func taskList(_ items: [(checked: Bool, inline: [MarkdownInline])]) -> some View {
        VStack(alignment: .leading, spacing: listItemGap(tight: true)) {
            ForEach(items.indices, id: \.self) { index in
                let item = items[index]
                HStack(alignment: .firstTextBaseline, spacing: Metrics.spacingSmall) {
                    Image(systemName: item.checked ? "checkmark.square.fill" : "square")
                        .font(Typo.body)
                        .foregroundStyle(item.checked ? Palette.positive : Palette.textTertiary)
                        .frame(width: markerWidth, alignment: .trailing)
                        .accessibilityLabel(item.checked ? "Done" : "Not done")
                    inlineText(item.inline, rung: Typo.body, color: foreground, spacing: listLineSpacing)
                        .lineSpacing(listLineSpacing)
                        .environment(\.markdownLineSpacingOverride, listLineSpacing)
                }
            }
        }
    }

    private func table(headers: [[MarkdownInline]], rows: [[[MarkdownInline]]], alignments: [TableAlignment]) -> some View {
        MarkdownTableLayout(columns: headers.count) {
            ForEach(headers.indices, id: \.self) { column in
                tableCell(
                    headers[column],
                    rung: Typo.labelEmphasis,
                    alignment: alignment(at: column, in: alignments),
                    isLastColumn: column == headers.count - 1,
                    isLastRow: rows.isEmpty
                )
                .background(Palette.surfaceSunken)
            }
            ForEach(rows.indices, id: \.self) { index in
                let row = rows[index]
                ForEach(row.indices, id: \.self) { column in
                    tableCell(
                        row[column],
                        rung: Typo.label,
                        alignment: alignment(at: column, in: alignments),
                        isLastColumn: column == row.count - 1,
                        isLastRow: index == rows.count - 1
                    )
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: Metrics.cornerSmall))
        .overlay {
            RoundedRectangle(cornerRadius: Metrics.cornerSmall)
                .strokeBorder(Palette.border, lineWidth: Metrics.outline)
        }
    }

    private func tableCell(
        _ inline: [MarkdownInline],
        rung: ScaledFont,
        alignment: Alignment,
        isLastColumn: Bool,
        isLastRow: Bool
    ) -> some View {
        inlineText(inline, rung: rung, color: foreground)
            .padding(.horizontal, Metrics.spacingWide)
            .padding(.vertical, Metrics.spacing)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)
            .overlay(alignment: .trailing) {
                if !isLastColumn { Hairline(axis: .vertical) }
            }
            .overlay(alignment: .bottom) {
                if !isLastRow { Hairline() }
            }
    }

    private func alignment(at index: Int, in alignments: [TableAlignment]) -> Alignment {
        guard alignments.indices.contains(index) else { return .leading }
        return switch alignments[index] {
        case .leading: .topLeading
        case .center: .top
        case .trailing: .topTrailing
        }
    }
}

@MainActor
enum InlineNSAttributes {
    static func make(
        _ inline: [MarkdownInline],
        font: NSFont,
        code: NSFont,
        color: NSColor,
        lineSpacing: CGFloat
    ) -> NSAttributedString {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = lineSpacing
        paragraph.lineBreakMode = .byWordWrapping

        let output = NSMutableAttributedString()
        render(inline, font: font, code: code, color: color, traits: [], into: output)
        TranscriptLink.addSourceIcons(to: output)
        output.addAttribute(
            .paragraphStyle, value: paragraph, range: NSRange(location: 0, length: output.length)
        )
        return output
    }

    private static func render(
        _ values: [MarkdownInline],
        font: NSFont,
        code: NSFont,
        color: NSColor,
        traits: NSFontTraitMask,
        into output: NSMutableAttributedString
    ) {
        for value in values {
            switch value {
            case let .text(text):
                let child = run(text, font: faced(font, traits), color: color)
                for (range, url) in SourceReference.links(in: text) { child.addAttribute(.link, value: url, range: range) }
                output.append(child)
            case let .emphasis(children):
                render(children, font: font, code: code, color: color, traits: traits.union(.italicFontMask), into: output)
            case let .strong(children):
                render(children, font: font, code: code, color: color, traits: traits.union(.boldFontMask), into: output)
            case let .strikethrough(children):
                let start = output.length
                render(children, font: font, code: code, color: color, traits: traits, into: output)
                output.addAttribute(
                    .strikethroughStyle, value: NSUnderlineStyle.single.rawValue,
                    range: NSRange(location: start, length: output.length - start)
                )
            case let .code(text):
                let child = run(text, font: faced(code, traits), color: color)
                child.addAttribute(
                    .backgroundColor, value: Palette.hoverNSColor,
                    range: NSRange(location: 0, length: child.length)
                )
                if let target = SourceReference.url(text) {
                    child.addAttribute(.link, value: target, range: NSRange(location: 0, length: child.length))
                }
                output.append(child)
            case let .link(text, url):
                let start = output.length
                render(text, font: font, code: code, color: color, traits: traits, into: output)
                if let target = SourceReference.url(url) ?? URL(string: url),
                   LinkPolicy.opens(target) || SourceReference.location(target) != nil {
                    output.addAttribute(
                        .link, value: target,
                        range: NSRange(location: start, length: output.length - start)
                    )
                }
            case .lineBreak:
                output.append(run("\n", font: faced(font, traits), color: color))
            }
        }
    }

    private static func run(_ text: String, font: NSFont, color: NSColor) -> NSMutableAttributedString {
        NSMutableAttributedString(string: text, attributes: [.font: font, .foregroundColor: color])
    }

    private static func faced(_ font: NSFont, _ traits: NSFontTraitMask) -> NSFont {
        guard !traits.isEmpty else { return font }
        return NSFontManager.shared.convert(font, toHaveTrait: traits)
    }

    static func hasLink(_ values: [MarkdownInline]) -> Bool {
        values.contains { value in
            switch value {
            case .link: true
            case let .emphasis(children), let .strong(children), let .strikethrough(children):
                hasLink(children)
            case let .code(text): SourceReference.url(text) != nil
            case let .text(text): !SourceReference.links(in: text).isEmpty
            case .lineBreak: false
            }
        }
    }
}

private final class InlineAttributesKey: NSObject {
    let inline: [MarkdownInline]
    let font: Font
    let code: Font
    let color: Color
    private let cachedHash: Int

    init(inline: [MarkdownInline], font: Font, code: Font, color: Color) {
        self.inline = inline
        self.font = font
        self.code = code
        self.color = color
        cachedHash = Self.hash(of: inline, font: font, code: code, color: color)
    }

    private static func hash(of inline: [MarkdownInline], font: Font, code: Font, color: Color) -> Int {
        var hasher = Hasher()
        hasher.combine(inline.count)
        if let first = inline.first { combine(first, into: &hasher) }
        if let last = inline.last, inline.count > 1 { combine(last, into: &hasher) }
        hasher.combine(font)
        hasher.combine(code)
        hasher.combine(color)
        return hasher.finalize()
    }

    private static let sample = 24

    private static func combine(_ value: MarkdownInline, into hasher: inout Hasher) {
        switch value {
        case let .text(text):
            hasher.combine(0)
            hasher.combine(text.utf8.count)
            hasher.combine(text.prefix(sample))
        case let .code(text):
            hasher.combine(1)
            hasher.combine(text.utf8.count)
            hasher.combine(text.prefix(sample))
        case let .emphasis(children):
            hasher.combine(2)
            hasher.combine(children.count)
        case let .strong(children):
            hasher.combine(3)
            hasher.combine(children.count)
        case let .strikethrough(children):
            hasher.combine(4)
            hasher.combine(children.count)
        case let .link(text, url):
            hasher.combine(5)
            hasher.combine(text.count)
            hasher.combine(url.utf8.count)
            hasher.combine(url.prefix(sample))
        case .lineBreak:
            hasher.combine(6)
        }
    }

    override var hash: Int { cachedHash }

    override func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? InlineAttributesKey else { return false }
        return cachedHash == other.cachedHash
            && inline == other.inline
            && font == other.font
            && code == other.code
            && color == other.color
    }
}

private final class InlineAttributesBox {
    let value: AttributedString

    init(_ value: AttributedString) { self.value = value }
}

@MainActor
private enum InlineAttributes {
    private static let values: NSCache<InlineAttributesKey, InlineAttributesBox> = {
        let cache = NSCache<InlineAttributesKey, InlineAttributesBox>()
        cache.countLimit = 1_000
        return cache
    }()

    static func make(
        _ inline: [MarkdownInline],
        font: Font,
        code: Font,
        color: Color
    ) -> AttributedString {
        let key = InlineAttributesKey(inline: inline, font: font, code: code, color: color)
        if let cached = values.object(forKey: key) { return cached.value }

        let value = render(inline, font: font, code: code, color: color, intents: [])
        values.setObject(InlineAttributesBox(value), forKey: key)
        return value
    }

    private static func render(
        _ values: [MarkdownInline],
        font: Font,
        code: Font,
        color: Color,
        intents: InlinePresentationIntent
    ) -> AttributedString {
        var output = AttributedString()
        for value in values {
            switch value {
            case let .text(text):
                output += run(text, font: font, color: color, intents: intents)
            case let .emphasis(children):
                output += render(children, font: font, code: code, color: color, intents: intents.union(.emphasized))
            case let .strong(children):
                output += render(children, font: font, code: code, color: color, intents: intents.union(.stronglyEmphasized))
            case let .strikethrough(children):
                var child = render(children, font: font, code: code, color: color, intents: intents)
                child.strikethroughStyle = .single
                output += child
            case let .code(text):
                var child = AttributedString(text)
                child.font = code
                child.foregroundColor = color
                child.backgroundColor = Palette.hover
                if !intents.isEmpty { child.inlinePresentationIntent = intents }
                output += child
            case let .link(text, url):
                if let target = SourceReference.url(url) ?? URL(string: url),
                   LinkPolicy.opens(target) || SourceReference.location(target) != nil {
                    var child = render(text, font: font, code: code, color: Palette.link, intents: intents)
                    child.foregroundColor = Palette.link
                    child.underlineStyle = .single
                    child.link = target
                    output += child
                } else {
                    output += render(text, font: font, code: code, color: color, intents: intents)
                }
            case .lineBreak:
                output += run("\n", font: font, color: color, intents: intents)
            }
        }
        return output
    }

    private static func run(_ text: String, font: Font, color: Color, intents: InlinePresentationIntent) -> AttributedString {
        var value = AttributedString(text)
        value.font = font
        value.foregroundColor = color
        if !intents.isEmpty { value.inlinePresentationIntent = intents }
        return value
    }
}
