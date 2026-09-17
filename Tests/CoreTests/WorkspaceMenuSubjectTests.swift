import Testing
@testable import Core

@Suite("What the Workspace menu acts on")
struct WorkspaceMenuSubjectTests {
    private let live = WorkspaceID("workspace-1")
    private let other = WorkspaceID("workspace-2")

    @Test("a selected workspace answers, with no list focused")
    func selectionAnswers() {
        #expect(
            WorkspaceMenuSubject.resolve(selection: .workspace(live), focusedRow: nil)
                == .live(live)
        )
        #expect(
            WorkspaceMenuSubject.resolve(selection: .archived(live), focusedRow: nil)
                == .archived(live)
        )
    }

    @Test("a highlighted row answers on the screen that has no workspace selected")
    func focusedRowAnswers() {
        #expect(
            WorkspaceMenuSubject.resolve(
                selection: .home,
                focusedRow: .init(id: live, isArchived: false)
            ) == .live(live)
        )
    }

    @Test("an archived row is not offered as a live one")
    func archivedRow() {
        #expect(
            WorkspaceMenuSubject.resolve(
                selection: .home, focusedRow: .init(id: live, isArchived: true)
            ) == .archived(live)
        )
    }

    @Test("reading a subagent still acts on its workspace")
    func subagent() {
        let subagent = SubagentID("subagent-1")
        #expect(
            WorkspaceMenuSubject.resolve(selection: .subagent(live, subagent), focusedRow: nil)
                == .live(live)
        )
    }

    @Test("a selected workspace wins over a row left behind by another screen")
    func selectionWins() {
        #expect(
            WorkspaceMenuSubject.resolve(
                selection: .workspace(live), focusedRow: .init(id: other, isArchived: false)
            ) == .live(live)
        )
    }

    @Test("nothing selected and nothing highlighted is nothing to act on")
    func nothing() {
        #expect(WorkspaceMenuSubject.resolve(selection: .home, focusedRow: nil) == nil)
    }

    @Test("a live workspace answers to everything but Restore")
    func liveActions() {
        let subject = WorkspaceMenuSubject.live(live)
        for action in WorkspaceMenuAction.allCases where action != .restore {
            #expect(subject.allows(action), "\(action)")
        }
        #expect(!subject.allows(.restore))
        #expect(subject.liveID == live)
        #expect(subject.archivedID == nil)
    }

    @Test("an archived workspace answers only to Restore and Copy Branch Name")
    func archivedActions() {
        let subject = WorkspaceMenuSubject.archived(live)
        #expect(subject.allows(.restore))
        #expect(subject.allows(.copyBranchName))
        #expect(!subject.allows(.archive))
        #expect(!subject.allows(.openInEditor))
        #expect(!subject.allows(.revealInFinder))
        #expect(!subject.allows(.rename))
        #expect(!subject.allows(.pin))
        #expect(!subject.allows(.unreadMark))
        #expect(!subject.allows(.colour))
        #expect(subject.allows(.copyName))
        #expect(subject.liveID == nil)
        #expect(subject.archivedID == live)
        #expect(subject.id == live)
    }

    @Test("every item in the menu is classified for both kinds of workspace")
    func everyActionIsClassified() {
        let live = WorkspaceMenuSubject.live(self.live)
        let archived = WorkspaceMenuSubject.archived(self.live)

        let bothAllow = WorkspaceMenuAction.allCases
            .filter { live.allows($0) && archived.allows($0) }
        #expect(bothAllow == [.copyBranchName, .copyName])

        let neitherAllows = WorkspaceMenuAction.allCases
            .filter { !live.allows($0) && !archived.allows($0) }
        #expect(neitherAllows.isEmpty)
    }
}
