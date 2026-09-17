import Foundation

public actor WorktreeCutQueue {
    public static let shared = WorktreeCutQueue()

    private var tails: [String: Task<Void, Never>] = [:]

    public init() {}

    public func cut<T: Sendable>(
        in repo: String,
        _ work: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        let previous = tails[repo]
        let run = Task<T, Error> {
            await previous?.value
            return try await work()
        }
        let finished = Task<Void, Never> { _ = try? await run.value }
        tails[repo] = finished
        return try await run.value
    }
}
