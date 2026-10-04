import Testing
@testable import Core

@Suite("Sidebar status group")
struct SidebarStatusGroupTests {
    @Test("a permission question and a failed setup both want a person")
    func needsYou() {
        #expect(SidebarStatusGroup.of(.awaitingPermission) == .needsYou)
        #expect(SidebarStatusGroup.of(.setupFailed) == .needsYou)
    }

    @Test("a finished turn nobody has read ranks above one still running")
    func readyToReadBeforeWorking() throws {
        #expect(SidebarStatusGroup.of(.unread) == .readyToRead)
        #expect(SidebarStatusGroup.of(.running) == .working)

        let order = SidebarStatusGroup.allCases
        let read = try #require(order.firstIndex(of: .readyToRead))
        let working = try #require(order.firstIndex(of: .working))
        #expect(read < working)
    }

    @Test("setting up counts as working")
    func settingUpIsWorking() {
        #expect(SidebarStatusGroup.of(.settingUp) == .working)
    }

    @Test("every pull request and branch state is idle", arguments: [
        WorkspaceStatus.merged, .closed, .conflicted, .checksFailing, .checksRunning, .checksPassed,
        .draft, .pullRequestOpen, .changed, .clean,
    ])
    func branchStatesAreIdle(_ status: WorkspaceStatus) {
        #expect(SidebarStatusGroup.of(status) == .idle)
    }

    @Test("an unread turn outranks the pull request for the section", arguments: [
        WorkspaceStatus.merged, .checksPassed, .pullRequestOpen, .changed,
    ])
    func unreadOutranksPullRequest(_ status: WorkspaceStatus) {
        #expect(SidebarStatusGroup.of(status, unread: true) == .readyToRead)
        #expect(SidebarStatusGroup.of(status, unread: false) == .idle)
    }

    @Test("a question or a running turn still outranks unread")
    func urgentStatesOutrankUnread() {
        #expect(SidebarStatusGroup.of(.awaitingPermission, unread: true) == .needsYou)
        #expect(SidebarStatusGroup.of(.running, unread: true) == .working)
        #expect(SidebarStatusGroup.of(.settingUp, unread: true) == .working)
    }

    @Test("the sections are drawn in this order, with these titles")
    func titles() {
        #expect(SidebarStatusGroup.allCases.map(\.title) == ["Needs you", "Ready to read", "Working", "Idle"])
    }

    @Test("only Idle ranks its rows by recency")
    func onlyIdleRanks() {
        #expect(SidebarStatusGroup.allCases.filter(\.ranksByRecency) == [.idle])
    }

    @Test("only Idle folds, and only once it holds enough rows")
    func folding() {
        #expect(SidebarStatusGroup.foldThreshold == 4)
        #expect(!SidebarStatusGroup.idle.canFold(count: 3))
        #expect(SidebarStatusGroup.idle.canFold(count: 4))
        for group in SidebarStatusGroup.allCases where group != .idle {
            #expect(!group.canFold(count: 40))
        }
    }
}
