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

    private struct Flight: Sendable {
        let id = UUID()
        let key: Key
        let task: Task<Bool, Never>
    }

    private let fetch: Fetch
    private let now: @Sendable () -> ContinuousClock.Instant
    private var inFlight: [Key: Flight] = [:]
    private var stopping: [Key: Flight] = [:]
    private var succeededAt: [Key: ContinuousClock.Instant] = [:]
    private var waiters: [UUID: Set<UUID>] = [:]
    private var prefetches: Set<UUID> = []

    private(set) var joined = 0

    var flights: Int { inFlight.count }

    var prefetchFlights: Int { prefetches.count }

    var waiting: Int { waiters.values.reduce(0) { $0 + $1.count } }

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
        for winding in stopping.values where winding.key.everyBranch == key.everyBranch {
            _ = await winding.task.value
        }
        if let running = covering.lazy.compactMap({ self.inFlight[$0] }).first {
            joined += 1
            return await wait(for: running)
        }
        if isPrefetch, prefetches.count >= Self.prefetchCeiling { return false }

        let fetch = self.fetch
        let flight = Flight(key: key, task: Task.detached(priority: Task.currentPriority) {
            await fetch(key.branch, key.directory, key.remote)
        })
        inFlight[key] = flight
        if isPrefetch { prefetches.insert(flight.id) }
        defer {
            if inFlight[key]?.id == flight.id { inFlight[key] = nil }
            if stopping[key]?.id == flight.id { stopping[key] = nil }
            prefetches.remove(flight.id)
            waiters[flight.id] = nil
        }

        let fetched = await wait(for: flight)
        if fetched { succeededAt[key] = now() }
        return fetched
    }

    private func wait(for flight: Flight) async -> Bool {
        let token = UUID()
        waiters[flight.id, default: []].insert(token)
        return await withTaskCancellationHandler {
            let value = await flight.task.value
            waiters[flight.id]?.remove(token)
            return value
        } onCancel: {
            Task { await self.leave(flight, token: token) }
        }
    }

    private func leave(_ flight: Flight, token: UUID) {
        waiters[flight.id]?.remove(token)
        guard waiters[flight.id]?.isEmpty ?? true else { return }
        flight.task.cancel()
        guard inFlight[flight.key]?.id == flight.id else { return }
        inFlight[flight.key] = nil
        stopping[flight.key] = flight
    }

    private func isFresh(_ key: Key, within age: Duration) -> Bool {
        guard let at = succeededAt[key] else { return false }
        return now() - at <= age
    }
}
