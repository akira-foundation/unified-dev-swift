import Foundation
import Testing
@testable import Core

@Suite("CanvasQuitFlush")
@MainActor
struct CanvasQuitFlushTests {
    @Test func aStuckFlushDoesNotHoldUpQuitting() async {
        var finished = false

        await CanvasQuitFlush.run(within: .milliseconds(50)) {
            try? await Task.sleep(for: .seconds(60))
            finished = true
        }

        #expect(finished == false)
    }

    @Test func aFlushThatFinishesIsAwaited() async {
        var finished = false

        await CanvasQuitFlush.run(within: .seconds(60)) {
            try? await Task.sleep(for: .milliseconds(20))
            finished = true
        }

        #expect(finished)
    }

    @Test func pendingCommitsFlushWhatIsScheduled() {
        let pending = CanvasPendingCommits()
        let commit = CanvasCoalescedCommit(delay: .seconds(60))
        pending.add(commit)
        var committed = 0
        commit.schedule { committed += 1 }

        pending.flush()
        pending.flush()

        #expect(committed == 1)
    }

    @Test func aPendingCommitFromAControlThatIsGoneIsForgotten() {
        let pending = CanvasPendingCommits()
        var commit: CanvasCoalescedCommit? = CanvasCoalescedCommit()
        if let commit { pending.add(commit) }
        weak let observed = commit
        var committed = 0
        commit?.schedule { committed += 1 }
        commit = nil

        pending.flush()

        #expect(observed == nil)
        #expect(committed == 0)
    }
}
