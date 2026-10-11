import Foundation
import Testing
@testable import Core

@Suite("When a workspace's mark is worth drawing")
struct SidebarMarkPolicyTests {
    @Test("a workspace with nothing to say has no mark")
    func cleanSaysNothing() {
        #expect(!SidebarMarkPolicy.saysSomething(.clean))
    }

    @Test("a workspace with changes has no mark either, because the diff numbers say it")
    func changedIsSaidByTheNumbers() {
        #expect(!SidebarMarkPolicy.saysSomething(.changed))
    }

    @Test("every state that asks for the reader keeps its mark", arguments: [
        WorkspaceStatus.settingUp, .awaitingPermission, .running, .setupFailed, .unread,
        .conflicted, .checksFailing, .checksRunning, .checksPassed,
    ])
    func whatAsksKeepsItsMark(status: WorkspaceStatus) {
        #expect(SidebarMarkPolicy.saysSomething(status))
    }

    @Test("every state about a pull request keeps its mark, because the row says nothing about one",
          arguments: [WorkspaceStatus.merged, .closed, .draft, .pullRequestOpen])
    func pullRequestStatesKeepTheirMark(status: WorkspaceStatus) {
        #expect(SidebarMarkPolicy.saysSomething(status))
    }

    @Test("the silent states are those two and no others")
    func onlyThoseTwoAreSilent() {
        #expect(SidebarMarkPolicy.silent == [.changed, .clean])
    }

    @Test("the states worth drawing are the other thirteen, in the enum's own order")
    func drawnIsEveryOtherState() {
        #expect(SidebarMarkPolicy.drawn == WorkspaceStatus.allCases.filter { $0 != .clean && $0 != .changed })
        #expect(SidebarMarkPolicy.drawn.count == 13)
        #expect(WorkspaceStatus.allCases.count == 13 + 2)
    }

    @Test("what a legend lists is every drawn state, split once, with nothing lost and nothing twice")
    func theTwoHalvesOfTheLegendCoverTheDrawnStates() {
        let both = SidebarMarkPolicy.drawnInTheWorkspace + SidebarMarkPolicy.drawnOnGitHub

        #expect(Set(both) == Set(SidebarMarkPolicy.drawn))
        #expect(both.count == SidebarMarkPolicy.drawn.count)
        #expect(SidebarMarkPolicy.drawnInTheWorkspace.allSatisfy { !$0.describesPullRequest })
        #expect(SidebarMarkPolicy.drawnOnGitHub.allSatisfy { $0.describesPullRequest })
        #expect(!SidebarMarkPolicy.drawnInTheWorkspace.contains(.clean))
        #expect(!SidebarMarkPolicy.drawnInTheWorkspace.contains(.changed))
    }
}
