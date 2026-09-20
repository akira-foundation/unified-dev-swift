import Foundation
import Testing
@testable import Core

@Suite("What a suggestion's card offers")
struct WorkSuggestionCardTests {
    private let context = WorkSuggestionCard.Context(projectName: "lantern", workspaceName: "Importer")

    private func suggestion(
        _ target: WorkSuggestion.Target = .sameProject,
        state: WorkSuggestion.State = .pending,
        failure: String? = nil
    ) -> WorkSuggestion {
        WorkSuggestion(
            stored: WorkSuggestionID("s1"), workspaceID: WorkspaceID("w1"), sessionID: SessionID("c1"),
            anchorSeq: 3, title: "Keep the last row", why: "Because.", prompt: "Do it.", target: target,
            state: state, failure: failure, createdAt: Date(timeIntervalSince1970: 0), decidedAt: nil
        )
    }

    @Test("work in this project offers New Workspace first, then Here, then Dismiss, each saying where")
    func sameProject() {
        let offers = WorkSuggestionCard.offers(for: suggestion(), in: context)

        #expect(offers.map(\.action) == [.newWorkspace, .here, .dismiss])
        #expect(offers.map(\.isProminent) == [true, false, false])
        #expect(offers[0].title == "New Workspace")
        #expect(offers[0].accessibilityLabel == "Start as a new workspace in lantern")
        #expect(offers[1].title == "Here")
        #expect(offers[1].accessibilityLabel == "Start here, as a subagent in Importer")
        #expect(WorkSuggestionCard.targetLine(for: suggestion(), in: context) == nil)
    }

    @Test("Here is not offered from a subagent's chat, nor from Ask, which is in no workspace", arguments: [
        WorkSuggestionCard.Context(projectName: "lantern", workspaceName: "Importer", chatIsSubagent: true),
        WorkSuggestionCard.Context(projectName: "lantern", workspaceName: nil),
    ])
    func noHere(context: WorkSuggestionCard.Context) {
        #expect(WorkSuggestionCard.offers(for: suggestion(), in: context).map(\.action) == [.newWorkspace, .dismiss])
    }

    @Test("work in another project offers New Workspace and names the project, hidden or not")
    func otherProject() {
        let other = suggestion(.project(RepoID("r-almanac")))
        let shown = WorkSuggestionCard.Context(projectName: "almanac", workspaceName: "Importer")
        let hidden = WorkSuggestionCard.Context(projectName: "almanac", workspaceName: "Importer", projectIsHidden: true)

        #expect(WorkSuggestionCard.offers(for: other, in: shown).map(\.action) == [.newWorkspace, .dismiss])
        #expect(WorkSuggestionCard.targetLine(for: other, in: shown) == "In almanac")
        #expect(WorkSuggestionCard.targetLine(for: other, in: hidden)?.contains("hidden") == true)
    }

    @Test("a folder not in Unified Dev offers Add Project and Start, and says it is not added yet")
    func folder() {
        let folder = suggestion(.folder("/Users/kid/tidewater"))
        let named = WorkSuggestionCard.Context(projectName: "tidewater", workspaceName: "Importer")

        let offers = WorkSuggestionCard.offers(for: folder, in: named)

        #expect(offers.map(\.action) == [.addProjectAndStart, .dismiss])
        #expect(offers[0].title == "Add Project and Start")
        #expect(WorkSuggestionCard.targetLine(for: folder, in: named)?.contains("/Users/kid/tidewater") == true)
        #expect(WorkSuggestionCard.targetLine(for: folder, in: named)?.contains("not in Unified Dev yet") == true)
    }

    @Test("a repository only on GitHub offers nothing to start, and says it has to be cloned")
    func remote() {
        let remote = suggestion(.remote("octo/parsekit"))

        #expect(WorkSuggestionCard.offers(for: remote, in: context).map(\.action) == [.dismiss])
        #expect(WorkSuggestionCard.targetLine(for: remote, in: context) == WorkSuggestionWording.cloneFirst("octo/parsekit"))
    }

    @Test("a card that is starting or decided offers nothing, and says what became of it", arguments: [
        (WorkSuggestion.State.starting, "Starting"),
        (.startedWorkspace(WorkspaceID("w-born"), name: "Last row"), "Started as Last row"),
        (.startedHere(SessionID("c-born"), name: "Last row"), "Started as Last row"),
        (.dismissed, "Dismissed"),
        (.withdrawn, "Withdrawn by the agent"),
    ])
    func decided(state: WorkSuggestion.State, line: String) {
        let card = suggestion(state: state)

        #expect(WorkSuggestionCard.offers(for: card, in: context).isEmpty)
        #expect(WorkSuggestionCard.statusLine(for: card) == line)
        #expect(!WorkSuggestionCard.opensAsDraft(card))
    }

    @Test("a card in a workspace another agent started offers only Here, because a grandchild is refused")
    func noNewWorkspaceFromAStartedWorkspace() {
        let started = WorkSuggestionCard.Context(
            projectName: "lantern", workspaceName: "Importer", workspaceWasStartedByAnAgent: true
        )

        let here = WorkSuggestionCard.offers(for: suggestion(), in: started)
        #expect(here.map(\.action) == [.here, .dismiss])
        #expect(here.map(\.isProminent) == [true, false])

        let elsewhere = WorkSuggestionCard.offers(for: suggestion(.project(RepoID("r-almanac"))), in: started)
        #expect(elsewhere.map(\.action) == [.dismiss])
    }

    @Test("a card that failed to start waits again and shows why")
    func failureShows() {
        let card = suggestion(failure: "Try again once one of them is archived.")

        #expect(WorkSuggestionCard.statusLine(for: card) == "Try again once one of them is archived.")
        #expect(WorkSuggestionCard.offers(for: card, in: context).map(\.action) == [.newWorkspace, .here, .dismiss])
    }

    @Test("only waiting work in a project Unified Dev has opens as a draft")
    func drafts() {
        #expect(WorkSuggestionCard.opensAsDraft(suggestion()))
        #expect(WorkSuggestionCard.opensAsDraft(suggestion(.project(RepoID("r-almanac")))))
        #expect(!WorkSuggestionCard.opensAsDraft(suggestion(.folder("/tmp/tidewater"))))
        #expect(!WorkSuggestionCard.opensAsDraft(suggestion(.remote("octo/parsekit"))))
    }

    @Test("VoiceOver hears the card as one group named after the work")
    func accessibility() {
        #expect(WorkSuggestionCard.accessibilityLabel(for: suggestion()) == "Suggested work: Keep the last row")
    }

    @Test("a card started as a workspace opens that workspace")
    func opensWorkspace() {
        let card = suggestion(state: .startedWorkspace(WorkspaceID("w-born"), name: "Last row"))

        #expect(WorkSuggestionCard.openTarget(for: card) == .workspace(WorkspaceID("w-born")))
    }

    @Test("a card started here opens the subagent's chat, unless it was never found")
    func opensSessionUnlessMissing() {
        let found = suggestion(state: .startedHere(SessionID("c-born"), name: "Last row"))
        let missing = suggestion(state: .startedHere(SessionID(""), name: "Last row"))

        #expect(WorkSuggestionCard.openTarget(for: found) == .session(SessionID("c-born")))
        #expect(WorkSuggestionCard.openTarget(for: missing) == nil)
    }

    @Test("a card not yet started, or not started as a session or a workspace, opens nothing", arguments: [
        WorkSuggestion.State.pending,
        .starting,
        .dismissed,
        .withdrawn,
    ])
    func opensNothing(state: WorkSuggestion.State) {
        #expect(WorkSuggestionCard.openTarget(for: suggestion(state: state)) == nil)
    }

    @Test("the sidebar marks a workspace only while something waits, and says how many")
    func sidebarMark() {
        #expect(WorkSuggestionSidebarMark.label(undecided: 0) == nil)
        #expect(WorkSuggestionSidebarMark.label(undecided: 1) == "1 suggestion to decide")
        #expect(WorkSuggestionSidebarMark.label(undecided: 3) == "3 suggestions to decide")
    }
    @Test("work in this chat's own project says so when that project is hidden, because a new workspace brings it back")
    func sameProjectHidden() {
        let hidden = WorkSuggestionCard.Context(projectName: "lantern", workspaceName: "Importer", projectIsHidden: true)

        let line = WorkSuggestionCard.targetLine(for: suggestion(), in: hidden)

        #expect(line?.contains("lantern") == true)
        #expect(line?.contains("hidden") == true)
    }

    @Test("each button starts the way it names, and Dismiss starts nothing")
    func buttonChoices() {
        #expect(WorkSuggestionCard.Action.newWorkspace.choice == .newWorkspace)
        #expect(WorkSuggestionCard.Action.addProjectAndStart.choice == .newWorkspace)
        #expect(WorkSuggestionCard.Action.here.choice == .here)
        #expect(WorkSuggestionCard.Action.dismiss.choice == nil)
    }
}
