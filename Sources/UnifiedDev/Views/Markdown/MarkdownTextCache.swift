import AppKit
import Core

struct MarkdownTextKey: Hashable {
    var text: String
    var isStreaming: Bool
    var style: MarkdownTextStyle
    var expanded: Set<Int>
    var footers: [Int: CGFloat]
}

private final class MarkdownTextKeyBox: NSObject {
    let key: MarkdownTextKey

    init(_ key: MarkdownTextKey) { self.key = key }

    override var hash: Int { key.hashValue }

    override func isEqual(_ object: Any?) -> Bool {
        (object as? MarkdownTextKeyBox)?.key == key
    }
}

@MainActor
enum MarkdownTextCache {
    private static let values: NSCache<MarkdownTextKeyBox, MarkdownText> = {
        let cache = NSCache<MarkdownTextKeyBox, MarkdownText>()
        cache.totalCostLimit = 32 * 1_024 * 1_024
        return cache
    }()

    private static var streamed: (key: MarkdownTextKey, text: MarkdownText)?

    static func text(for key: MarkdownTextKey, blocks: [MarkdownBlock]) -> MarkdownText {
        var builder = MarkdownTextBuilder(
            style: key.style, isStreaming: key.isStreaming, expanded: key.expanded, footers: key.footers
        )
        guard key.isStreaming else {
            let box = MarkdownTextKeyBox(key)
            if let held = values.object(forKey: box) { return held }
            let text = builder.build(blocks, continuing: nil)
            values.setObject(text, forKey: box, cost: key.text.utf8.count * 8)
            return text
        }
        if let streamed, streamed.key == key { return streamed.text }
        let previous = streamed.flatMap { $0.key.style == key.style && $0.key.footers == key.footers ? $0.text : nil }
        let text = builder.build(blocks, continuing: previous)
        streamed = (key, text)
        return text
    }
}
