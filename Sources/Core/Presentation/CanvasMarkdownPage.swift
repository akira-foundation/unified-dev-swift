import Foundation

public enum CanvasMarkdownPage {
    public static func isMarkdown(path: String) -> Bool {
        ["md", "markdown"].contains((path as NSString).pathExtension.lowercased())
    }

    public static func html(from source: String, title: String) -> String {
        let body = MarkdownParser.parse(source).map(block).joined(separator: "\n")
        return """
        <!doctype html>
        <html>
        <head>
        <meta charset="utf-8">
        <meta name="color-scheme" content="light dark">
        <title>\(escape(title))</title>
        <style>\(stylesheet)</style>
        </head>
        <body>
        \(body)
        </body>
        </html>
        """
    }

    static func escape(_ text: String) -> String {
        var result = ""
        result.reserveCapacity(text.count)
        for character in text {
            switch character {
            case "&": result += "&amp;"
            case "<": result += "&lt;"
            case ">": result += "&gt;"
            case "\"": result += "&quot;"
            case "'": result += "&#39;"
            default: result.append(character)
            }
        }
        return result
    }

    static func block(_ block: MarkdownBlock) -> String {
        switch block {
        case let .paragraph(inline):
            "<p>\(inlines(inline))</p>"
        case let .heading(level, inline):
            heading(level: level, inline: inline)
        case let .codeBlock(code, _, info):
            codeBlock(code: code, info: info)
        case let .bulletList(items, _):
            "<ul>\(items.map(listItem).joined())</ul>"
        case let .numberedList(start, items, _):
            "<ol start=\"\(start)\">\(items.map(listItem).joined())</ol>"
        case let .taskList(items):
            "<ul class=\"tasks\">\(items.map(taskItem).joined())</ul>"
        case let .blockQuote(blocks):
            "<blockquote>\(blocks.map(Self.block).joined())</blockquote>"
        case let .table(headers, rows, alignments):
            table(headers: headers, rows: rows, alignments: alignments)
        case .thematicBreak:
            "<hr>"
        }
    }

    private static func heading(level: Int, inline: [MarkdownInline]) -> String {
        let level = min(max(level, 1), 6)
        return "<h\(level)>\(inlines(inline))</h\(level)>"
    }

    private static func codeBlock(code: String, info: String) -> String {
        let language = info.split(separator: " ").first.map { " class=\"language-\(escape(String($0)))\"" } ?? ""
        return "<pre><code\(language)>\(escape(code))</code></pre>"
    }

    private static func listItem(_ blocks: [MarkdownBlock]) -> String {
        "<li>\(blocks.map(block).joined())</li>"
    }

    private static func taskItem(_ item: (checked: Bool, inline: [MarkdownInline])) -> String {
        let checked = item.checked ? " checked" : ""
        return "<li><input type=\"checkbox\" disabled\(checked)> \(inlines(item.inline))</li>"
    }

    private static func table(
        headers: [[MarkdownInline]], rows: [[[MarkdownInline]]], alignments: [TableAlignment]
    ) -> String {
        func cell(_ tag: String, _ index: Int, _ content: [MarkdownInline]) -> String {
            let alignment = index < alignments.count ? alignments[index] : .leading
            let style = switch alignment {
            case .leading: ""
            case .center: " style=\"text-align:center\""
            case .trailing: " style=\"text-align:right\""
            }
            return "<\(tag)\(style)>\(inlines(content))</\(tag)>"
        }
        let head = headers.enumerated().map { cell("th", $0.offset, $0.element) }.joined()
        let body = rows.map { row in
            "<tr>" + row.enumerated().map { cell("td", $0.offset, $0.element) }.joined() + "</tr>"
        }.joined()
        return "<table><thead><tr>\(head)</tr></thead><tbody>\(body)</tbody></table>"
    }
}
