import Testing
import Foundation
@testable import Core

@Suite("Spend poll schedule")
struct SpendPollScheduleTests {
    private let now = Date(timeIntervalSince1970: 1_791_676_800)

    @Test("a first read is always due")
    func firstRead() {
        #expect(SpendPollSchedule.isDue(lastReadAt: nil, at: now, after: 20))
    }

    @Test("a read a moment after the last one is not due")
    func tooSoon() {
        #expect(!SpendPollSchedule.isDue(
            lastReadAt: now.addingTimeInterval(-5), at: now, after: SpendPollSchedule.onDemandFloor
        ))
    }

    @Test("a read after the floor is due again")
    func dueAgain() {
        #expect(SpendPollSchedule.isDue(
            lastReadAt: now.addingTimeInterval(-SpendPollSchedule.onDemandFloor),
            at: now,
            after: SpendPollSchedule.onDemandFloor
        ))
    }
}
