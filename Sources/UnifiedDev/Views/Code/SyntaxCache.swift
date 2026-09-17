import SwiftUI
import AppKit
import Core

private final class SyntaxBox {
    let value: AttributedString

    init(_ value: AttributedString) { self.value = value }
}

enum SyntaxCache {
    private static let limit = 4_000

    nonisolated(unsafe) private static let storage: NSCache<SyntaxCacheKey, SyntaxBox> = {
        let cache = NSCache<SyntaxCacheKey, SyntaxBox>()
        cache.countLimit = limit
        return cache
    }()

    static func attributed(line: String, language: Language, carry: LexState) -> AttributedString {
        let key = SyntaxCacheKey(line: line, language: language, carry: carry)
        if let hit = storage.object(forKey: key) { return hit.value }

        let value = build(line: line, language: language, carry: carry)
        storage.setObject(SyntaxBox(value), forKey: key)
        return value
    }

    private static func build(line: String, language: Language, carry: LexState) -> AttributedString {
        var value = AttributedString(line)
        value.foregroundColor = Palette.textPrimary
        guard !line.isEmpty else { return value }

        var state = carry
        let tokens = SyntaxHighlighter.tokenize(line: line, language: language, carry: &state)

        for token in tokens where token.kind != .plain {
            guard let range = CodeText.attributedRange(
                forUTF16: token.range, of: line, in: value
            ) else { continue }
            value[range].foregroundColor = CodeText.color(for: token.kind)
        }
        return value
    }
}
