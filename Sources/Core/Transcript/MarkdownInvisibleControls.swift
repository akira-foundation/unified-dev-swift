import Foundation

public enum MarkdownInvisibleControls {
    private static let controls: CharacterSet = {
        var set = CharacterSet(charactersIn: "\u{202A}\u{202B}\u{202C}\u{202D}\u{202E}\u{2066}\u{2067}\u{2068}\u{2069}\u{200B}")
        set.insert(charactersIn: Unicode.Scalar(0x00)!...Unicode.Scalar(0x08)!)
        set.insert(charactersIn: Unicode.Scalar(0x0B)!...Unicode.Scalar(0x1F)!)
        set.insert(charactersIn: Unicode.Scalar(0x7F)!...Unicode.Scalar(0x9F)!)
        set.insert(charactersIn: Unicode.Scalar(0xE0000)!...Unicode.Scalar(0xE007F)!)
        return set
    }()

    public static func stripped(_ text: String) -> String {
        guard text.unicodeScalars.contains(where: controls.contains) else { return text }
        return String(String.UnicodeScalarView(text.unicodeScalars.filter { !controls.contains($0) }))
    }

    public static func stripped(_ body: MarkdownPiece.Body) -> MarkdownPiece.Body {
        switch body {
        case let .text(inline, heading):
            return .text(stripped(inline), heading: heading)
        case let .code(code, language, info):
            return .code(code: stripped(code), language: language, info: info)
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
