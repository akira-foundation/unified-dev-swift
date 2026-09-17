import Foundation

public enum LinkPolicy {
    public static func opens(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased() else { return false }
        return scheme == "https" || scheme == "http" || scheme == "mailto"
    }

    public static func shortened(_ url: String) -> String {
        var value = url
        for scheme in ["https://", "http://"] where value.hasPrefix(scheme) {
            value.removeFirst(scheme.count)
        }
        guard value.count > 48 else { return value }
        return value.prefix(47) + "\u{2026}"
    }

    public static func addresses(in text: String) -> [String] {
        addresses(of: LinkScan.links(in: text))
    }

    public static func addresses(of links: [DetectedLink]) -> [String] {
        deduplicated(links.map(\.url))
    }

    public static func addresses(in blocks: [MarkdownBlock]) -> [String] {
        var found: [String] = []
        for block in blocks { collect(block, into: &found) }
        return deduplicated(found)
    }

    private static func collect(_ block: MarkdownBlock, into found: inout [String]) {
        switch block {
        case let .paragraph(inline):
            collect(inline, into: &found)
        case let .heading(_, inline):
            collect(inline, into: &found)
        case let .bulletList(items, _), let .numberedList(_, items, _):
            for item in items { for child in item { collect(child, into: &found) } }
        case let .taskList(items):
            for item in items { collect(item.inline, into: &found) }
        case let .blockQuote(blocks):
            for child in blocks { collect(child, into: &found) }
        case let .table(headers, rows, _):
            for header in headers { collect(header, into: &found) }
            for row in rows { for cell in row { collect(cell, into: &found) } }
        case .codeBlock, .thematicBreak:
            break
        }
    }

    private static func collect(_ inline: [MarkdownInline], into found: inout [String]) {
        for value in inline {
            switch value {
            case let .link(text, url):
                if let parsed = URL(string: url), opens(parsed) { found.append(url) }
                collect(text, into: &found)
            case let .emphasis(children), let .strong(children), let .strikethrough(children):
                collect(children, into: &found)
            case .text, .code, .lineBreak:
                break
            }
        }
    }

    private static func deduplicated(_ values: [String]) -> [String] {
        var seen: Set<String> = []
        return values.filter { seen.insert($0).inserted }
    }
}
