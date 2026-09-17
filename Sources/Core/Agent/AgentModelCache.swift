import Foundation

actor AgentModelCache<Model: Sendable> {
    static var freshness: TimeInterval { 15 * 60 }

    private let fetch: @Sendable () async throws -> [Model]
    private let now: @Sendable () -> Date
    private var cached: [Model] = []
    private var fetchedAt: Date?
    private var inFlight: Task<[Model], Error>?
    private(set) var fetchCount = 0

    init(
        fetch: @escaping @Sendable () async throws -> [Model],
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.fetch = fetch
        self.now = now
    }

    func models() async throws -> [Model] {
        if let fetchedAt, now().timeIntervalSince(fetchedAt) < Self.freshness, !cached.isEmpty {
            return cached
        }

        let task: Task<[Model], Error>
        if let running = inFlight {
            task = running
        } else {
            fetchCount += 1
            let fetch = self.fetch
            task = Task { try await fetch() }
            inFlight = task
        }

        defer { if inFlight == task { inFlight = nil } }
        let models = try await task.value
        if inFlight == task {
            cached = models
            fetchedAt = now()
        }
        return models
    }

    func invalidate() {
        cached = []
        fetchedAt = nil
        inFlight = nil
    }

    var lastKnown: [Model] { cached }
}
