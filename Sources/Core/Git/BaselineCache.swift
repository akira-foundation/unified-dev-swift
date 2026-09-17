import Foundation

enum BaselineFingerprint {
    static func arguments(base: String, remote: String) -> [String] {
        ["rev-parse", "--revs-only", "HEAD", base, "refs/remotes/\(remote)/\(base)"]
    }

    static func make(_ output: String) -> String? {
        let lines = output
            .split(separator: "\n", omittingEmptySubsequences: true)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        guard !lines.isEmpty else { return nil }
        return lines.joined(separator: " ")
    }
}

actor BaselineCache {
    static let shared = BaselineCache()

    static let limit = 256

    private struct Key: Hashable {
        let worktree: String
        let base: String
    }

    private struct Entry {
        let fingerprint: String
        let baseline: String
        var usedAt: UInt64
    }

    private struct Flight: Hashable {
        let key: Key
        let fingerprint: String
    }

    private var entries: [Key: Entry] = [:]
    private var inFlight: [Flight: Task<String, Error>] = [:]

    private var clock: UInt64 = 0

    func baseline(worktree: String, base: String, fingerprint: String) -> String? {
        let key = Key(worktree: worktree, base: base)
        guard var entry = entries[key], entry.fingerprint == fingerprint else { return nil }
        clock += 1
        entry.usedAt = clock
        entries[key] = entry
        return entry.baseline
    }

    func remember(worktree: String, base: String, fingerprint: String, baseline: String) {
        clock += 1
        entries[Key(worktree: worktree, base: base)] = Entry(
            fingerprint: fingerprint, baseline: baseline, usedAt: clock
        )
        guard entries.count > Self.limit else { return }
        let oldest = entries
            .sorted { $0.value.usedAt < $1.value.usedAt }
            .prefix(entries.count - Self.limit)
        for (key, _) in oldest { entries[key] = nil }
    }

    func baseline(
        worktree: String,
        base: String,
        fingerprint: String,
        resolve: @escaping @Sendable () async throws -> String
    ) async throws -> String {
        if let remembered = baseline(worktree: worktree, base: base, fingerprint: fingerprint) {
            return remembered
        }

        let flight = Flight(key: Key(worktree: worktree, base: base), fingerprint: fingerprint)
        if let running = inFlight[flight] { return try await running.value }

        let task = Task.detached(priority: Task.currentPriority) { try await resolve() }
        inFlight[flight] = task
        defer { inFlight[flight] = nil }

        let answer = try await task.value
        remember(worktree: worktree, base: base, fingerprint: fingerprint, baseline: answer)
        return answer
    }

    var count: Int { entries.count }

    var flights: Int { inFlight.count }
}
