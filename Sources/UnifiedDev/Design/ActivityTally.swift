import Foundation

@MainActor
enum ActivityTally {
    static var reloads = 0
    static var inboxReloads = 0

    struct Reading {
        var reloads: Int
        var inboxReloads: Int

        static func - (lhs: Reading, rhs: Reading) -> Reading {
            Reading(reloads: lhs.reloads - rhs.reloads, inboxReloads: lhs.inboxReloads - rhs.inboxReloads)
        }
    }

    static func read() -> Reading {
        Reading(reloads: reloads, inboxReloads: inboxReloads)
    }
}
