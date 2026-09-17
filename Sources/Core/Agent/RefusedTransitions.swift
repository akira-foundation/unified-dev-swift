import Foundation
import os
import Synchronization

public enum RefusedTransitions {
    public struct Entry: Sendable, Hashable {
        public var machine: String
        public var from: String
        public var event: String
        public var at: Date

        public init(machine: String, from: String, event: String, at: Date = Date()) {
            self.machine = machine
            self.from = from
            self.event = event
            self.at = at
        }

        public var sentence: String {
            "\(machine) refused \(event) from \(from)"
        }
    }

    private static let limit = 200

    private static let entries = Mutex<[Entry]>([])
    private static let refusals = Mutex<Int>(0)

    private static let log = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "io.akira.unifieddev",
        category: "transitions"
    )

    static func record(machine: String, from: String, event: String, at: Date = Date()) {
        let entry = Entry(machine: machine, from: from, event: event, at: at)
        refusals.withLock { $0 += 1 }
        entries.withLock {
            $0.append(entry)
            if $0.count > limit { $0.removeFirst($0.count - limit) }
        }
        log.error("\(entry.sentence, privacy: .public)")
    }

    public static var recent: [Entry] { entries.withLock { $0 } }

    public static var count: Int { refusals.withLock { $0 } }

    public static func forget() {
        entries.withLock { $0 = [] }
        refusals.withLock { $0 = 0 }
    }
}
