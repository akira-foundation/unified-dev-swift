import Foundation

public actor BaseBranchFetches {
    public static let shared = BaseBranchFetches()

    public static let recent: Duration = .seconds(120)

    typealias Fetch = @Sendable (_ branch: String, _ directory: String, _ remote: String) async -> Bool

    private struct Key: Hashable {
        let directory: String
        let remote: String
        let branch: String
    }

    private let fetch: Fetch
    private let now: @Sendable () -> ContinuousClock.Instant
    private var inFlight: [Key: Task<Bool, Never>] = [:]
    private var succeededAt: [Key: ContinuousClock.Instant] = [:]

    private(set) var joined = 0

    var flights: Int { inFlight.count }

    init(
        fetch: @escaping Fetch = { await Git.fetch($0, in: $1, remote: $2) },
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
        let key = Key(directory: directory, remote: remote, branch: branch)
        if let age, let at = succeededAt[key], now() - at <= age { return true }
        if let running = inFlight[key] {
            joined += 1
            return await running.value
        }

        let fetch = self.fetch
        let task = Task.detached(priority: Task.currentPriority) {
            await fetch(branch, directory, remote)
        }
        inFlight[key] = task
        defer { inFlight[key] = nil }

        let fetched = await task.value
        if fetched { succeededAt[key] = now() }
        return fetched
    }
}
