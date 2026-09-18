import Foundation

public actor BaseBranchFetches {
    public static let shared = BaseBranchFetches()

    public static let recent: Duration = .seconds(120)

    static let prefetchCeiling = 2

    typealias Fetch = @Sendable (_ branch: String?, _ directory: String, _ remote: String) async -> Bool

    private struct Key: Hashable {
        let directory: String
        let remote: String
        let branch: String?

        var everyBranch: Key { Key(directory: directory, remote: remote, branch: nil) }
    }

    private let fetch: Fetch
    private let now: @Sendable () -> ContinuousClock.Instant
    private var inFlight: [Key: Task<Bool, Never>] = [:]
    private var succeededAt: [Key: ContinuousClock.Instant] = [:]
    private var waiters: [Key: Set<UUID>] = [:]
    private var prefetches: Set<Key> = []

    private(set) var joined = 0

    var flights: Int { inFlight.count }

    var prefetchFlights: Int { prefetches.count }

    init(
        fetch: @escaping Fetch = { branch, directory, remote in
            guard let branch else { return await Git.fetchBranches(from: remote, in: directory) }
            return await Git.fetch(branch, in: directory, remote: remote)
        },
        now: @escaping @Sendable () -> ContinuousClock.Instant = { ContinuousClock.now }
    ) {
        self.fetch = fetch
        self.now = now
    }

    public static func prefetch(base: String, in directory: String) async {
        guard Git.isValidBranchName(base),
              let names = try? await Git.remoteNames(of: directory),
              let remote = Git.primaryRemote(of: names)
        else { return }
        _ = await shared.prefetch(base, in: directory, remote: remote)
    }

    public func refresh(
        _ branch: String, in directory: String, remote: String, acceptingWithin age: Duration? = nil
    ) async -> Bool {
        await run(Key(directory: directory, remote: remote, branch: branch), acceptingWithin: age)
    }

    public func refreshBranches(
        in directory: String, remote: String, acceptingWithin age: Duration? = nil
    ) async -> Bool {
        await run(Key(directory: directory, remote: remote, branch: nil), acceptingWithin: age)
    }

    func prefetch(_ branch: String, in directory: String, remote: String) async -> Bool {
        await run(
            Key(directory: directory, remote: remote, branch: branch),
            acceptingWithin: Self.recent,
            isPrefetch: true
        )
    }

    private func run(_ key: Key, acceptingWithin age: Duration?, isPrefetch: Bool = false) async -> Bool {
        let covering = age == nil ? [key] : [key, key.everyBranch]
        if let age, covering.contains(where: { isFresh($0, within: age) }) { return true }
        if let running = covering.first(where: { inFlight[$0] != nil }), let task = inFlight[running] {
            joined += 1
            return await wait(for: task, under: running)
        }
        if isPrefetch, prefetches.count >= Self.prefetchCeiling { return false }

        let fetch = self.fetch
        let task = Task.detached(priority: Task.currentPriority) {
            await fetch(key.branch, key.directory, key.remote)
        }
        inFlight[key] = task
        if isPrefetch { prefetches.insert(key) }
        defer {
            inFlight[key] = nil
            prefetches.remove(key)
            waiters[key] = nil
        }

        let fetched = await wait(for: task, under: key)
        if fetched { succeededAt[key] = now() }
        return fetched
    }

    private func wait(for task: Task<Bool, Never>, under key: Key) async -> Bool {
        let token = UUID()
        waiters[key, default: []].insert(token)
        return await withTaskCancellationHandler {
            let value = await task.value
            waiters[key]?.remove(token)
            return value
        } onCancel: {
            Task { await self.leave(key, token: token, task: task) }
        }
    }

    private func leave(_ key: Key, token: UUID, task: Task<Bool, Never>) {
        waiters[key]?.remove(token)
        guard waiters[key]?.isEmpty ?? true else { return }
        task.cancel()
    }

    private func isFresh(_ key: Key, within age: Duration) -> Bool {
        guard let at = succeededAt[key] else { return false }
        return now() - at <= age
    }
}
