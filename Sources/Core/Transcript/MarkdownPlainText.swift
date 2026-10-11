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
            nonEmpty(indent + text(of: inline))
        case .heading(_, let inline):
            nonEmpty(indent + text(of: inline))
        case .codeBlock(let code, _, _):
            nonEmpty(indented(code, by: indent))
        case .bulletList(let items, _):
            joined(items.map { item(marker: "\u{2022} ", blocks: $0, indent: indent) })
        case .numberedList(let start, let items, _):
            joined(items.enumerated().map { item(marker: "\($0.offset + start). ", blocks: $0.element, indent: indent) })
        case .taskList(let items):
            joined(items.map { [indent + ($0.checked ? "\u{2713} " : "\u{25A1} ") + text(of: $0.inline)] })
        case .blockQuote(let blocks):
            paragraphs(of: blocks, indent: indent)
        case .table(let headers, let rows, _):
            joined(([headers] + rows).map { [indent + $0.map { text(of: $0) }.joined(separator: "  ")] })
        case .thematicBreak:
            []
        }
    }

    private static func item(marker: String, blocks: [MarkdownBlock], indent: String) -> [String] {
        let inner = paragraphs(of: blocks, indent: indent + String(repeating: " ", count: marker.count))
        guard let first = inner.first else { return [] }
        return [indent + marker + first.trimmingCharacters(in: .whitespaces)] + inner.dropFirst()
    }

    private static func joined(_ groups: [[String]]) -> [String] {
        let lines = groups.flatMap { $0 }
        return lines.isEmpty ? [] : [lines.joined(separator: "\n")]
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

    private static func text(of inline: [MarkdownInline]) -> String {
        inline.map { piece in
            switch piece {
            case .text(let value):
                value
            case .emphasis(let inner), .strong(let inner), .strikethrough(let inner):
                text(of: inner)
            case .code(let value):
                value
            case .link(let inner, let url):
                link(text(of: inner), url: url)
            case .lineBreak:
                "\n"
            }
        }
        .joined()
    }

    private static func link(_ label: String, url: String) -> String {
        label.isEmpty || label == url ? url : "\(label) (\(url))"
    }
}
