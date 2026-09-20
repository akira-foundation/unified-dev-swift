import Foundation
import Testing
@testable import Core

@Suite("Where a suggestion's card says the work would go")
struct WorkSuggestionCardContextTests {
    private let lantern = Repo(id: RepoID("r-lantern"), name: "lantern", path: "/work/lantern")
    private let almanac = Repo(id: RepoID("r-almanac"), name: "almanac", path: "/work/almanac", hidden: true)
    private var importer: Workspace {
        Workspace(
            id: WorkspaceID("w1"), repoID: lantern.id, name: "Importer",
            branch: "importer", path: "/work/lantern-importer", baseBranch: "main"
        )
    }

    private func suggestion(
        _ target: WorkSuggestion.Target,
        from workspaceID: WorkspaceID? = WorkspaceID("w1"),
        state: WorkSuggestion.State = .pending
    ) -> WorkSuggestion {
        WorkSuggestion(
            stored: WorkSuggestionID("s1"), workspaceID: workspaceID, sessionID: SessionID("c1"),
            anchorSeq: nil, title: "Keep the last row", why: "Because.", prompt: "Do it.", target: target,
            state: state, failure: nil, createdAt: Date(timeIntervalSince1970: 0), decidedAt: nil
        )
    }

    private func context(_ suggestion: WorkSuggestion, chatIsSubagent: Bool = false) -> WorkSuggestionCard.Context {
        .of(suggestion, workspaces: [importer], repos: [lantern, almanac], chatIsSubagent: chatIsSubagent)
    }

    @Test("a workspace another agent started is marked as such, so its card can drop New Workspace")
    func startedByAnAgent() {
        let helper = Workspace(
            id: WorkspaceID("w2"), repoID: lantern.id, name: "Helper",
            branch: "helper", path: "/work/lantern-helper", baseBranch: "main",
            origin: .agent(parentWorkspaceID: WorkspaceID("w1"), spawnToolUseID: "toolu_1")
        )
        let found = WorkSuggestionCard.Context.of(
            suggestion(.sameProject, from: helper.id),
            workspaces: [importer, helper], repos: [lantern, almanac], chatIsSubagent: false
        )

        #expect(found.workspaceWasStartedByAnAgent)
        #expect(!context(suggestion(.sameProject)).workspaceWasStartedByAnAgent)
    }

    @Test("work in this project names the suggesting workspace's project and the workspace")
    func sameProject() {
        let found = context(suggestion(.sameProject), chatIsSubagent: true)

        #expect(found == WorkSuggestionCard.Context(
            projectName: "lantern", workspaceName: "Importer", projectIsHidden: false, chatIsSubagent: true
        ))
    }

    @Test("work in this project from a workspace no longer open says this project, and has no workspace")
    func sameProjectGone() {
        let found = context(suggestion(.sameProject, from: WorkspaceID("w-gone")))

        #expect(found.projectName == "this project")
        #expect(found.workspaceName == nil)
    }

    @Test("another project is named, and a hidden one says so")
    func otherProject() {
        let found = context(suggestion(.project(almanac.id)))

        #expect(found.projectName == "almanac")
        #expect(found.projectIsHidden)
        #expect(found.workspaceName == "Importer")
    }

    @Test("a project removed from Unified Dev is named as such")
    func removedProject() {
        let found = context(suggestion(.project(RepoID("r-gone"))))

        #expect(found.projectName == "a project no longer in Unified Dev")
        #expect(!found.projectIsHidden)
    }

    @Test("a folder is named by its last path component, a remote by its slug", arguments: [
        (WorkSuggestion.Target.folder("/Users/kid/tidewater/"), "tidewater"),
        (WorkSuggestion.Target.remote("akira-io/tidewater"), "akira-io/tidewater"),
    ])
    func outside(target: WorkSuggestion.Target, name: String) {
        let found = context(suggestion(target, from: nil))

        #expect(found.projectName == name)
        #expect(found.workspaceName == nil)
        #expect(!found.projectIsHidden)
    }

    @Test("Open as Draft opens the suggesting workspace's project, or the named one")
    func draftProject() {
        let same = WorkSuggestionCard.draftProject(
            for: suggestion(.sameProject), workspaces: [importer], repos: [lantern, almanac]
        )
        let other = WorkSuggestionCard.draftProject(
            for: suggestion(.project(almanac.id)), workspaces: [importer], repos: [lantern, almanac]
        )

        #expect(same?.id == lantern.id)
        #expect(other?.id == almanac.id)
    }

    @Test("Open as Draft opens nothing for a folder, a remote, a removed project or a decided card", arguments: [
        (WorkSuggestion.Target.folder("/Users/kid/tidewater"), WorkSuggestion.State.pending),
        (WorkSuggestion.Target.remote("akira-io/tidewater"), WorkSuggestion.State.pending),
        (WorkSuggestion.Target.project(RepoID("r-gone")), WorkSuggestion.State.pending),
        (WorkSuggestion.Target.sameProject, WorkSuggestion.State.dismissed),
    ])
    func noDraft(target: WorkSuggestion.Target, state: WorkSuggestion.State) {
        let found = WorkSuggestionCard.draftProject(
            for: suggestion(target, state: state), workspaces: [importer], repos: [lantern, almanac]
        )

        #expect(found == nil)
    }
}
