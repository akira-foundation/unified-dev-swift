import Testing
@testable import Core

@Suite("Workspace start hold")
struct WorkspaceStartHoldTests {
    @Test("a running agent takes over from the hold, and nothing else is let go")
    func settlesOnRunning() {
        let first = WorkspaceID.new()
        let second = WorkspaceID.new()
        var hold = WorkspaceStartHold()
        hold.begin(first)
        hold.begin(second)

        hold.settle(running: [first, WorkspaceID.new()])

        #expect(!hold.contains(first))
        #expect(hold.contains(second))
    }

    @Test("settling against agents that were never held changes nothing")
    func settleWithoutOverlap() {
        var hold = WorkspaceStartHold()
        hold.begin(WorkspaceID.new())
        let before = hold

        hold.settle(running: [WorkspaceID.new()])

        #expect(hold == before)
    }

    @Test("a start that ends without an agent lets go by hand")
    func releases() {
        let id = WorkspaceID.new()
        var hold = WorkspaceStartHold()
        hold.begin(id)

        hold.release(id)

        #expect(hold.ids.isEmpty)
    }

    @Test("a chat start lets go at once, and an agent in a terminal gets ten seconds to report")
    func releaseDelay() {
        #expect(WorkspaceStartHold.releaseDelay(afterCLILaunch: false) == nil)
        #expect(WorkspaceStartHold.releaseDelay(afterCLILaunch: true) == .seconds(10))
    }
}
