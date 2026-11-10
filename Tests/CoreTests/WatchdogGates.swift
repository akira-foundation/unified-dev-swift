import Foundation

final class WatchdogGates: @unchecked Sendable {
    private let lock = NSLock()
    private var requested: [Duration] = []
    private var waiting: [UUID: CheckedContinuation<Void, Error>] = [:]

    var asked: [Duration] {
        lock.withLock { requested }
    }

    func sleep(_ duration: Duration) async throws {
        let id = UUID()
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                park(id, asking: duration, continuation)
            }
        } onCancel: {
            wake(id)
        }
    }

    private func park(_ id: UUID, asking duration: Duration, _ continuation: CheckedContinuation<Void, Error>) {
        lock.lock()
        requested.append(duration)
        let cancelled = Task.isCancelled
        if !cancelled { waiting[id] = continuation }
        lock.unlock()
        if cancelled { continuation.resume(throwing: CancellationError()) }
    }

    private func wake(_ id: UUID) {
        lock.lock()
        let parked = waiting.removeValue(forKey: id)
        lock.unlock()
        parked?.resume(throwing: CancellationError())
    }

    func expireTheOneLeft(afterAsking count: Int) async {
        while !Task.isCancelled {
            if let expired = takeTheOneLeft(afterAsking: count) {
                expired.resume()
                return
            }
            await Task.yield()
        }
        expireAll()
    }

    private func expireAll() {
        lock.lock()
        let parked = Array(waiting.values)
        waiting.removeAll()
        lock.unlock()
        for continuation in parked { continuation.resume() }
    }

    private func takeTheOneLeft(afterAsking count: Int) -> CheckedContinuation<Void, Error>? {
        lock.lock()
        defer { lock.unlock() }
        guard requested.count >= count, waiting.count == 1, let id = waiting.keys.first else { return nil }
        return waiting.removeValue(forKey: id)
    }
}
