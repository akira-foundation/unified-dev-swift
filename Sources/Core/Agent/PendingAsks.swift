import Foundation
import Synchronization

final class PendingAsks: Sendable {
    private let asks = Mutex<[PermissionAsk]>([])

    var all: [PermissionAsk] { asks.withLock { $0 } }

    var isEmpty: Bool { asks.withLock(\.isEmpty) }

    func add(_ ask: PermissionAsk) {
        asks.withLock { asks in
            guard !asks.contains(where: { $0.requestID == ask.requestID }) else { return }
            asks.append(ask)
        }
    }

    func take(_ requestID: String) -> PermissionAsk? {
        asks.withLock { asks -> PermissionAsk? in
            guard let index = asks.firstIndex(where: { $0.requestID == requestID }) else { return nil }
            return asks.remove(at: index)
        }
    }

    func contains(_ requestID: String) -> Bool {
        asks.withLock { asks in asks.contains { $0.requestID == requestID } }
    }

    func remove(_ requestID: String) {
        asks.withLock { $0.removeAll { $0.requestID == requestID } }
    }

    func drain() -> [PermissionAsk] {
        asks.withLock { asks in
            let all = asks
            asks = []
            return all
        }
    }
}
