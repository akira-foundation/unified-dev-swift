import Foundation

public struct DiffPresentation: Sendable {
    public var source: FileDiff
    public var document: DiffDocument
    public var lines: [String]?

    public init(source: FileDiff, document: DiffDocument, lines: [String]?) {
        self.source = source
        self.document = document
        self.lines = lines
    }
}

public struct DiffPresentationCache: Sendable {
    public struct Key: Hashable, Sendable {
        public var worktree: String
        public var base: String
        public var file: String
        public var change: ChangedFile.Change
        public var scope: DiffScope
        public var ignoresWhitespace: Bool

        public init(
            worktree: String,
            base: String,
            file: ChangedFile,
            scope: DiffScope,
            ignoresWhitespace: Bool
        ) {
            self.worktree = worktree
            self.base = base
            self.file = file.path
            self.change = file.change
            self.scope = scope
            self.ignoresWhitespace = ignoresWhitespace
        }
    }

    public static let capacity = 6

    private var held: [Key: DiffPresentation] = [:]
    private var order: [Key] = []

    public init() {}

    public var count: Int { held.count }

    public func presentation(for key: Key) -> DiffPresentation? {
        held[key]
    }

    public mutating func store(_ presentation: DiffPresentation, for key: Key) {
        if held[key] == nil || order.last != key {
            order.removeAll { $0 == key }
            order.append(key)
        }
        held[key] = presentation

        while order.count > Self.capacity {
            let oldest = order.removeFirst()
            held[oldest] = nil
        }
    }

    public mutating func forget(file path: String) {
        let stale = order.filter { $0.file == path }
        for key in stale { held[key] = nil }
        order.removeAll { $0.file == path }
    }
}
