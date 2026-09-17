import Foundation

public struct PatchCache: Sendable {
    public struct Key: Hashable, Sendable {
        public var worktree: String
        public var base: String
        public var file: String
        public var change: ChangedFile.Change
        public var scope: DiffScope
        public var generation: Int

        public init(
            worktree: String,
            base: String,
            file: ChangedFile,
            scope: DiffScope,
            generation: Int
        ) {
            self.worktree = worktree
            self.base = base
            self.file = file.path
            self.change = file.change
            self.scope = scope
            self.generation = generation
        }
    }

    public static let capacity = 12

    private var patches: [Key: String] = [:]
    private var order: [Key] = []

    public init() {}

    public var count: Int { patches.count }

    public func patch(for key: Key) -> String? {
        patches[key]
    }

    public mutating func store(_ patch: String, for key: Key) {
        if patches[key] == nil || order.last != key {
            order.removeAll { $0 == key }
            order.append(key)
        }
        patches[key] = patch

        let superseded = order.filter { $0.generation != key.generation }
        for stale in superseded { patches[stale] = nil }
        order.removeAll { $0.generation != key.generation }

        while order.count > Self.capacity {
            let oldest = order.removeFirst()
            patches[oldest] = nil
        }
    }
}
