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

private final class SyntaxNSBox {
    let value: NSAttributedString

    init(_ value: NSAttributedString) { self.value = value }
}

extension SyntaxCache {
    nonisolated(unsafe) private static let nsStorage: NSCache<SyntaxCacheKey, SyntaxNSBox> = {
        let cache = NSCache<SyntaxCacheKey, SyntaxNSBox>()
        cache.countLimit = limit
        cache.totalCostLimit = 32 * 1_024 * 1_024
        return cache
    }()

    static func attributedNS(line: String, language: Language, carry: LexState) -> NSAttributedString {
        let key = SyntaxCacheKey(line: line, language: language, carry: carry)
        if let hit = nsStorage.object(forKey: key) { return hit.value }

        let value = NSMutableAttributedString(string: line, attributes: [.foregroundColor: NSColor.labelColor])
        if !line.isEmpty {
            var state = carry
            for token in SyntaxHighlighter.tokenize(line: line, language: language, carry: &state) where token.kind != .plain {
                let range = NSRange(location: token.range.lowerBound, length: token.range.count)
                guard NSMaxRange(range) <= value.length else { continue }
                value.addAttribute(.foregroundColor, value: NSColor(CodeText.color(for: token.kind)), range: range)
            }
        }
        nsStorage.setObject(SyntaxNSBox(value), forKey: key, cost: line.utf8.count * 4)
        return value
    }
}
