#if DEBUG
import Foundation

@MainActor
enum ActivityTally {
    static var reloads = 0
    static var inboxReloads = 0
    static var changeReads = 0
    static var changeGenerations = 0

    struct Reading {
        var reloads: Int
        var inboxReloads: Int
        var changeReads: Int
        var changeGenerations: Int

        static func - (lhs: Reading, rhs: Reading) -> Reading {
            Reading(
                reloads: lhs.reloads - rhs.reloads,
                inboxReloads: lhs.inboxReloads - rhs.inboxReloads,
                changeReads: lhs.changeReads - rhs.changeReads,
                changeGenerations: lhs.changeGenerations - rhs.changeGenerations
            )
        }
    }

    static func read() -> Reading {
        Reading(
            reloads: reloads, inboxReloads: inboxReloads,
            changeReads: changeReads, changeGenerations: changeGenerations
        )
    }
}
#endif
