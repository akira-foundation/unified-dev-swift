import Foundation

public enum MarkdownBidiControls {
    private static let controls = CharacterSet(charactersIn: "\u{202A}\u{202B}\u{202C}\u{202D}\u{202E}\u{2066}\u{2067}\u{2068}\u{2069}")

    public static func stripped(_ text: String) -> String {
        guard text.unicodeScalars.contains(where: controls.contains) else { return text }
        return String(String.UnicodeScalarView(text.unicodeScalars.filter { !controls.contains($0) }))
    }

    public static func stripped(_ body: MarkdownPiece.Body) -> MarkdownPiece.Body {
        switch body {
        case let .text(inline, heading):
            return .text(stripped(inline), heading: heading)
        case let .code(code, language, info):
            return .code(code: stripped(code), language: language, info: stripped(info))
        case var .cell(cell):
            cell.inline = stripped(cell.inline)
            return .cell(cell)
        case .rule:
            return .rule
        }
    }

    private static func stripped(_ inline: [MarkdownInline]) -> [MarkdownInline] {
        inline.map { piece in
            switch piece {
            case let .text(value): .text(stripped(value))
            case let .emphasis(inner): .emphasis(stripped(inner))
            case let .strong(inner): .strong(stripped(inner))
            case let .strikethrough(inner): .strikethrough(stripped(inner))
            case let .code(value): .code(stripped(value))
            case let .link(inner, url): .link(text: stripped(inner), url: url)
            case .lineBreak: .lineBreak
            }
        }
    }
}
