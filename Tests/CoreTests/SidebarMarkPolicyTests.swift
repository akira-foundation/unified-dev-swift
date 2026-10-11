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

    @Test("every state is decided one way or the other, and a new one has to be decided too")
    func everyStateIsDecided() {
        let decided = WorkspaceStatus.allCases.filter {
            SidebarMarkPolicy.saysSomething($0) || SidebarMarkPolicy.silent.contains($0)
        }

        #expect(decided.count == WorkspaceStatus.allCases.count)
        #expect(SidebarMarkPolicy.silent == [.clean, .changed])
    }

    @Test("two of the fifteen are silent, and the other thirteen are not")
    func thirteenKeepTheirMark() {
        let speaking = WorkspaceStatus.allCases.filter(SidebarMarkPolicy.saysSomething)

        #expect(WorkspaceStatus.allCases.count == 15)
        #expect(speaking.count == 13)
        #expect(SidebarMarkPolicy.silent.count == 2)
    }

    @Test("a state that says something is never also silent")
    func noStateIsBoth() {
        let both = WorkspaceStatus.allCases.filter {
            SidebarMarkPolicy.saysSomething($0) && SidebarMarkPolicy.silent.contains($0)
        }

        #expect(both.isEmpty)
    }
}
