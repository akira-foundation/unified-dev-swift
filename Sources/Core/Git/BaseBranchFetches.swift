import Foundation

public actor BaseBranchFetches {
    public static let shared = BaseBranchFetches()

    public static let recent: Duration = .seconds(120)

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

    private(set) var joined = 0

    var flights: Int { inFlight.count }

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
        _ = await shared.refresh(base, in: directory, remote: remote, acceptingWithin: recent)
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

    private func run(_ key: Key, acceptingWithin age: Duration?) async -> Bool {
        let covering = age == nil ? [key] : [key, key.everyBranch]
        if let age, covering.contains(where: { isFresh($0, within: age) }) { return true }
        if let running = covering.lazy.compactMap({ self.inFlight[$0] }).first {
            joined += 1
            return await running.value
        }

        let fetch = self.fetch
        let task = Task.detached(priority: Task.currentPriority) {
            await fetch(key.branch, key.directory, key.remote)
        }
        inFlight[key] = task
        defer { inFlight[key] = nil }

        let fetched = await task.value
        if fetched { succeededAt[key] = now() }
        return fetched
    }

    private func isFresh(_ key: Key, within age: Duration) -> Bool {
        guard let at = succeededAt[key] else { return false }
        return now() - at <= age
    }
}
