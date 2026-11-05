import Foundation

struct CanvasImageBudget<Key: Hashable, Value> {
    private struct Entry {
        let value: Value
        let bytes: Int
        var leases = 0
        var lastUsed: Int
    }

    let limit: Int
    private var entries: [Key: Entry] = [:]
    private var useCount = 0
    private(set) var bytesHeld = 0

    init(limit: Int) {
        self.limit = limit
    }

    var leasesHeld: Int { entries.values.reduce(0) { $0 + $1.leases } }

    func firstKey(where matches: (Key) -> Bool) -> Key? {
        entries.keys.first(where: matches)
    }

    mutating func lease(_ key: Key) -> Value? {
        guard var entry = entries[key] else { return nil }
        useCount += 1
        entry.leases += 1
        entry.lastUsed = useCount
        entries[key] = entry
        return entry.value
    }

    mutating func release(_ key: Key) {
        entries[key]?.leases -= 1
    }

    mutating func makeRoom(for bytes: Int) -> Bool {
        let free = entries.filter { $0.value.leases == 0 }
        let freeBytes = free.values.reduce(0) { $0 + $1.bytes }
        guard bytesHeld - freeBytes + bytes <= limit else { return false }
        for (key, entry) in free.sorted(by: { $0.value.lastUsed < $1.value.lastUsed }) where bytesHeld + bytes > limit {
            entries[key] = nil
            bytesHeld -= entry.bytes
        }
        return true
    }

    mutating func add(_ value: Value, bytes: Int, for key: Key) {
        useCount += 1
        entries[key] = Entry(value: value, bytes: bytes, lastUsed: useCount)
        bytesHeld += bytes
    }
}
