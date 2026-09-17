import Testing
import Foundation
@testable import Core

@Suite("Workspace marks")
struct WorkspaceMarkTests {
    private func workspace(
        unread: Bool = false,
        state: WorkspaceState = .active,
        colour: String? = nil
    ) -> Workspace {
        Workspace(
            repoID: RepoID("r"), name: "w", branch: "b", path: "/tmp/w", baseBranch: "main",
            state: state, unread: unread, colour: colour
        )
    }

    @Test("a read workspace is offered the mark, an unread one is offered its removal")
    func theItemChangesItsLabel() {
        #expect(WorkspaceUnreadMark.action(for: workspace()) == .markUnread)
        #expect(WorkspaceUnreadMark.action(for: workspace(unread: true)) == .markRead)
    }

    @Test("the item always writes the opposite of what is there")
    func theItemInverts() throws {
        for unread in [true, false] {
            let action = try #require(WorkspaceUnreadMark.action(for: workspace(unread: unread)))
            #expect(action.unread == !unread)
        }
    }

    @Test("the titles are the words the menu shows")
    func theTitlesAreTheWords() {
        #expect(UnreadMarkAction.markUnread.title == "Mark as Unread")
        #expect(UnreadMarkAction.markRead.title == "Mark as Read")
    }

    @Test("an archived workspace is offered nothing, however its flag stands")
    func archivedIsOfferedNothing() {
        #expect(WorkspaceUnreadMark.action(for: workspace(state: .archived)) == nil)
        #expect(WorkspaceUnreadMark.action(for: workspace(unread: true, state: .archived)) == nil)
    }

    @Test("every colour offered is one of the ten the app already hands to projects")
    func theColoursAreTheAccentSet() {
        for colour in WorkspaceColour.all {
            #expect(Accent.all.contains(colour.hex), "\(colour.name) is not an accent colour")
        }
        #expect(Set(WorkspaceColour.all.map(\.hex)).count == WorkspaceColour.all.count)
        #expect(Set(WorkspaceColour.all.map(\.name)).count == WorkspaceColour.all.count)
        #expect(Set(WorkspaceColour.all.map(\.hex)) == Set(Accent.all))
    }

    @Test("a stored colour is looked up whatever case it was written in")
    func lookupIgnoresCase() {
        #expect(WorkspaceColour.named("4C8DF6")?.name == "Blue")
        #expect(WorkspaceColour.named("4c8df6")?.name == "Blue")
        #expect(WorkspaceColour.named("nonsense") == nil)
    }

    @Test("a colour outside the list is still a colour")
    func anUnlistedColourIsStillDrawn() {
        let subject = workspace(colour: "7F3FBF")
        #expect(subject.colourMark == HexColor(red: 0x7F, green: 0x3F, blue: 0xBF))
        #expect(subject.colourDescription == "#7F3FBF")
    }

    @Test("no colour, and a value that is not one, both draw nothing")
    func nonsenseDrawsNothing() {
        #expect(workspace().colourMark == nil)
        #expect(workspace().colourDescription == nil)
        #expect(workspace(colour: "not a colour").colourMark == nil)
        #expect(workspace(colour: "not a colour").colourDescription == nil)
        #expect(workspace(colour: "").colourMark == nil)
    }

    @Test("a colour in the list is described by its name")
    func aListedColourIsNamed() {
        #expect(workspace(colour: "22A06B").colourDescription == "Green")
    }
}
