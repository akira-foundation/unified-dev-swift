import Synchronization

final class MarkdownInlineCache: Sendable {
    private struct State {
        var values: [[UInt8]: [MarkdownInline]] = [:]
        var order: [[UInt8]] = []
        var bytes = 0
    }

    private let state = Mutex(State())
    private let maximumEntries: Int
    private let maximumBytes: Int

    init(maximumEntries: Int = 512, maximumBytes: Int = 512 * 1_024) {
        self.maximumEntries = max(0, maximumEntries)
        self.maximumBytes = max(0, maximumBytes)
    }

    func value(for source: String, build: () -> [MarkdownInline]) -> [MarkdownInline] {
        let key = Array(source.utf8)
        if let cached = state.withLock({ $0.values[key] }) { return cached }
        let result = build()
        let bytes = key.count
        guard maximumEntries > 0, bytes <= maximumBytes else { return result }
        state.withLock { storage in
            guard storage.values[key] == nil else { return }
            while !storage.order.isEmpty,
                  storage.order.count >= maximumEntries || storage.bytes + bytes > maximumBytes {
                let oldest = storage.order.removeFirst()
                storage.values[oldest] = nil
                storage.bytes -= oldest.count
            }
            storage.values[key] = result
            storage.order.append(key)
            storage.bytes += bytes
        }
        return result
    }
}
