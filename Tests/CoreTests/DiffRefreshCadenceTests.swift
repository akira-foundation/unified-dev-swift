import Foundation
import Testing
@testable import Core

@Suite("How often the diff stat poll runs")
struct DiffRefreshCadenceTests {
    @Test("a window behind another app is read on the slower of the two intervals")
    func backgroundIsTheSlowerInterval() {
        #expect(DiffRefreshSchedule.backgroundTick > DiffRefreshSchedule.tick)
    }

    @Test("each activity answers with its own interval")
    func intervalPerActivity() {
        #expect(DiffRefreshSchedule.tick(for: .foreground) == DiffRefreshSchedule.tick)
        #expect(DiffRefreshSchedule.tick(for: .background) == DiffRefreshSchedule.backgroundTick)
    }

    @Test("ten seconds is a tick in front and not one behind")
    func tenSeconds() {
        let now = ContinuousClock.now
        let lastRun = now.advanced(by: .seconds(-10))

        #expect(DiffRefreshSchedule.isDue(activity: .foreground, lastRun: lastRun, now: now))
        #expect(!DiffRefreshSchedule.isDue(activity: .background, lastRun: lastRun, now: now))
    }

    @Test("a window behind another app comes round once its own interval has passed")
    func backgroundComesRound() {
        let now = ContinuousClock.now
        let lastRun = now.advanced(by: .seconds(-DiffRefreshSchedule.backgroundTick - 1))

        #expect(DiffRefreshSchedule.isDue(activity: .background, lastRun: lastRun, now: now))
    }

    @Test("the interval is reached rather than exceeded")
    func exactlyOnTheInterval() {
        let now = ContinuousClock.now

        #expect(DiffRefreshSchedule.isDue(
            activity: .background,
            lastRun: now.advanced(by: .seconds(-DiffRefreshSchedule.backgroundTick)),
            now: now
        ))
    }

    @Test("the first tick of a launch is not held back by either interval")
    func firstTick() {
        let now = ContinuousClock.now

        #expect(DiffRefreshSchedule.isDue(activity: .foreground, lastRun: nil, now: now))
        #expect(DiffRefreshSchedule.isDue(activity: .background, lastRun: nil, now: now))
    }

    @Test("bringing the window forward does not wait out the slower interval")
    func forwardAgainAfterABackgroundTick() {
        let now = ContinuousClock.now
        let lastRun = now.advanced(by: .seconds(-DiffRefreshSchedule.tick))

        #expect(DiffRefreshSchedule.isDue(activity: .foreground, lastRun: lastRun, now: now))
    }

    @Test("an hour asleep is one tick late rather than a reading that never comes")
    func afterTheMachineSlept() {
        let now = ContinuousClock.now
        let lastRun = now.advanced(by: .seconds(-3_600))

        #expect(DiffRefreshSchedule.isDue(activity: .foreground, lastRun: lastRun, now: now))
        #expect(DiffRefreshSchedule.isDue(activity: .background, lastRun: lastRun, now: now))
    }

    @Test("work for a window nobody is looking at is scheduled behind work for one that is")
    func backgroundIsTheLowerPriority() {
        #expect(DiffRefreshSchedule.priority(for: .background)
            < DiffRefreshSchedule.priority(for: .foreground))
    }

    @Test("each activity answers with its own priority")
    func priorityPerActivity() {
        #expect(DiffRefreshSchedule.priority(for: .foreground) == .userInitiated)
        #expect(DiffRefreshSchedule.priority(for: .background) == .utility)
    }
}
