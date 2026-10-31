import Foundation

extension CanvasMarkdownPage {
    static func inlines(_ items: [MarkdownInline]) -> String {
        var output = ""
        var index = 0
        while index < items.count {
            if let image = image(at: index, in: items) {
                output += image
                index += 2
                continue
            }
            output += inline(items[index])
            index += 1
        }
        return output
    }

    private static func image(at index: Int, in items: [MarkdownInline]) -> String? {
        guard index + 1 < items.count,
              case let .text(before) = items[index], before.hasSuffix("!"),
              case let .link(text, url) = items[index + 1]
        else { return nil }
        let leading = escape(String(before.dropLast()))
        let alt = escape(plainText(text))
        guard let source = safeAddress(url) else { return leading + alt }
        return leading + "<img src=\"\(escape(source))\" alt=\"\(alt)\">"
    }

    private static func inline(_ item: MarkdownInline) -> String {
        switch item {
        case let .text(text): escape(text)
        case let .emphasis(children): "<em>\(inlines(children))</em>"
        case let .strong(children): "<strong>\(inlines(children))</strong>"
        case let .strikethrough(children): "<del>\(inlines(children))</del>"
        case let .code(code): "<code>\(escape(code))</code>"
        case .lineBreak: "<br>"
        case let .link(text, url): link(text: text, url: url)
        }
    }

    private static func link(text: [MarkdownInline], url: String) -> String {
        guard let target = safeAddress(url) else { return inlines(text) }
        return "<a href=\"\(escape(target))\">\(inlines(text))</a>"
    }

    private static func plainText(_ items: [MarkdownInline]) -> String {
        items.map { item in
            switch item {
            case let .text(text), let .code(text): text
            case let .emphasis(children), let .strong(children), let .strikethrough(children): plainText(children)
            case let .link(text, _): plainText(text)
            case .lineBreak: " "
            }
        }.joined()
    }

    static func safeAddress(_ address: String) -> String? {
        let stripped = String(address.unicodeScalars.filter { !isInvisible($0) })
        let trimmed = stripped.trimmingCharacters(in: .whitespaces)
        let target = withoutTitle(trimmed).replacingOccurrences(of: " ", with: "%20")
        guard !target.isEmpty, !target.hasPrefix("//") else { return nil }
        guard let colon = target.firstIndex(of: ":") else { return target }
        let scheme = target[..<colon]
        if scheme.contains(where: { "/?#".contains($0) }) { return target }
        return ["http", "https", "mailto"].contains(scheme.lowercased()) ? target : nil
    }

    private static func withoutTitle(_ address: String) -> String {
        guard let space = address.firstIndex(of: " ") else { return address }
        let rest = address[address.index(after: space)...].trimmingCharacters(in: .whitespaces)
        guard rest.count >= 2, let first = rest.first, "\"'".contains(first), rest.last == first else { return address }
        return String(address[..<space])
    }

    private static func isInvisible(_ scalar: Unicode.Scalar) -> Bool {
        CharacterSet.controlCharacters.contains(scalar)
            || CharacterSet.newlines.contains(scalar)
            || scalar.properties.generalCategory == .format
    }
}
