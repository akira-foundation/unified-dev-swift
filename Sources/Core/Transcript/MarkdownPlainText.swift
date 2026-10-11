import Foundation

enum MarkdownPlainText {
    static func render(_ markdown: String) -> String {
        render(MarkdownParser.parse(markdown))
    }

    private static func render(_ blocks: [MarkdownBlock]) -> String {
        paragraphs(of: blocks, indent: "")
            .joined(separator: "\n\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func paragraphs(of blocks: [MarkdownBlock], indent: String) -> [String] {
        blocks.flatMap { paragraphs(of: $0, indent: indent) }
    }

    private static func paragraphs(of block: MarkdownBlock, indent: String) -> [String] {
        switch block {
        case .paragraph(let inline):
            nonEmpty(indent + text(of: inline, continuation: "\n" + indent))
        case .heading(_, let inline):
            nonEmpty(indent + text(of: inline, continuation: "\n" + indent))
        case .codeBlock(let code, _, _):
            nonEmpty(indented(clean(code), by: indent))
        case .bulletList(let items, let tight):
            list(items.map { item(marker: "\u{2022} ", blocks: $0, indent: indent, tight: tight) }, tight: tight)
        case .numberedList(let start, let items, let tight):
            list(
                items.enumerated().map {
                    item(marker: "\($0.offset + start). ", blocks: $0.element, indent: indent, tight: tight)
                },
                tight: tight
            )
        case .taskList(let items):
            list(
                items.map {
                    let marker = $0.checked ? "\u{2713} " : "\u{25A1} "
                    return [indent + marker + text(of: $0.inline, continuation: "\n" + indent + pad(marker))]
                },
                tight: true
            )
        case .blockQuote(let blocks):
            paragraphs(of: blocks, indent: indent)
        case .table(let headers, let rows, _):
            list(([headers] + rows).map { [indent + $0.map { text(of: $0, continuation: " ") }.joined(separator: "  ")] }, tight: true)
        case .thematicBreak:
            []
        }
    }

    private static func item(marker: String, blocks: [MarkdownBlock], indent: String, tight: Bool) -> [String] {
        let inner = indent + pad(marker)
        let written = paragraphs(of: blocks, indent: inner)
        guard let first = written.first else { return [] }
        let head = indent + marker + (first.hasPrefix(inner) ? String(first.dropFirst(inner.count)) : first)
        let rest = Array(written.dropFirst())
        guard tight else { return [head] + rest }
        return [([head] + rest).joined(separator: "\n")]
    }

    private static func list(_ items: [[String]], tight: Bool) -> [String] {
        let written = items.flatMap { $0 }
        guard !written.isEmpty else { return [] }
        return tight ? [written.joined(separator: "\n")] : written
    }

    private static func pad(_ marker: String) -> String {
        String(repeating: " ", count: marker.count)
    }

    private static func indented(_ text: String, by indent: String) -> String {
        guard !indent.isEmpty else { return text }
        return text.split(separator: "\n", omittingEmptySubsequences: false)
            .map { indent + $0 }
            .joined(separator: "\n")
    }

    private static func nonEmpty(_ line: String) -> [String] {
        line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? [] : [line]
    }

    private static func text(of inline: [MarkdownInline], continuation: String) -> String {
        inline.map { piece in
            switch piece {
            case .text(let value):
                clean(value)
            case .emphasis(let inner), .strong(let inner), .strikethrough(let inner):
                text(of: inner, continuation: continuation)
            case .code(let value):
                clean(value)
            case .link(let inner, let url):
                link(text(of: inner, continuation: continuation), url: clean(url))
            case .lineBreak:
                continuation
            }
        }
        .joined()
    }

    private static func link(_ label: String, url: String) -> String {
        label.isEmpty || label == url ? url : "\(label) (\(url))"
    }

    private static func clean(_ value: String) -> String {
        let kept = value.unicodeScalars.filter { !forbidden.contains($0) || $0 == "\n" || $0 == "\t" }
        return String(String.UnicodeScalarView(kept))
    }

    private static let forbidden = CharacterSet.controlCharacters
        .union(CharacterSet(charactersIn: "\u{2028}\u{2029}"))
}
