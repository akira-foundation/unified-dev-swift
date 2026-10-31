import Foundation

extension [MarkdownInline] {
    var unlinked: [MarkdownInline] {
        var result: [MarkdownInline] = []
        for value in flatMap(\.withoutLinks) {
            guard case let .text(text) = value, case let .text(previous)? = result.last else {
                result.append(value)
                continue
            }
            result[result.count - 1] = .text(previous + text)
        }
        return result
    }
}

private extension MarkdownInline {
    var withoutLinks: [MarkdownInline] {
        switch self {
        case let .link(text, _): text.unlinked
        case let .emphasis(children): [.emphasis(children.unlinked)]
        case let .strong(children): [.strong(children.unlinked)]
        case let .strikethrough(children): [.strikethrough(children.unlinked)]
        case .text, .code, .lineBreak: [self]
        }
    }
}
