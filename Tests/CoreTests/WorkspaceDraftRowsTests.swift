import Foundation
import Testing
@testable import Core

@Suite("The draft row in the sidebar")
struct WorkspaceDraftRowsTests {
    @Test("the row shows while it is open, while it holds text, and while it is being created")
    func whenItShows() {
        #expect(WorkspaceDraftRows.shows(hasContent: false, isOpen: true, isCreating: false, hasFailed: false))
        #expect(WorkspaceDraftRows.shows(hasContent: true, isOpen: false, isCreating: false, hasFailed: false))
        #expect(WorkspaceDraftRows.shows(hasContent: false, isOpen: false, isCreating: true, hasFailed: false))
        #expect(!WorkspaceDraftRows.shows(hasContent: false, isOpen: false, isCreating: false, hasFailed: false))
    }

    @Test("an empty draft is discarded on the way out, one with text is kept")
    func leaving() {
        #expect(WorkspaceDraftRows.departure(hasContent: false, isCreating: false, hasFailed: false) == .discard)
        #expect(WorkspaceDraftRows.departure(hasContent: true, isCreating: false, hasFailed: false) == .keep)
        #expect(WorkspaceDraftRows.departure(hasContent: false, isCreating: true, hasFailed: false) == .keep)
    }

    @Test("a draft whose create failed stays in the sidebar, with its reason, until it is dealt with")
    func failedDraftStays() {
        #expect(WorkspaceDraftRows.shows(hasContent: false, isOpen: false, isCreating: false, hasFailed: true))
        #expect(WorkspaceDraftRows.departure(hasContent: false, isCreating: false, hasFailed: true) == .keep)
    }

    @Test("the draft sits after the workspaces and the ones being cut")
    func afterEverythingElse() {
        #expect(WorkspaceDraftRows.slots(isCollapsed: false, workspaceCount: 2, pendingCount: 1, showsDraft: true)
            == [.workspaces, .pending, .draft])
    }

    @Test("a project with nothing but a draft has no empty notice")
    func draftReplacesTheNotice() {
        #expect(WorkspaceDraftRows.slots(isCollapsed: false, workspaceCount: 0, pendingCount: 0, showsDraft: true)
            == [.workspaces, .pending, .draft])
        #expect(WorkspaceDraftRows.slots(isCollapsed: false, workspaceCount: 0, pendingCount: 0, showsDraft: false)
            == [.emptyNotice])
    }

    @Test("a folded project still shows its draft, and nothing else")
    func foldedProject() {
        #expect(WorkspaceDraftRows.slots(isCollapsed: true, workspaceCount: 3, pendingCount: 0, showsDraft: true)
            == [.draft])
        #expect(WorkspaceDraftRows.slots(isCollapsed: true, workspaceCount: 3, pendingCount: 0, showsDraft: false)
            .isEmpty)
    }

    @Test("a workspace being cut from a draft is drawn as the draft, not twice")
    func pendingFromADraftIsHidden() {
        let fromDraft = PendingWorkspace(id: WorkspaceID("w1"), repoID: RepoID("r"), name: "Coral Sea")
        let other = PendingWorkspace(id: WorkspaceID("w2"), repoID: RepoID("r"), name: "Bell")
        #expect(WorkspaceDraftRows.drawnPending([fromDraft, other], creating: [WorkspaceID("w1")]) == [other])
    }

    @Test("VoiceOver reads the row as a draft")
    func spoken() {
        #expect(WorkspaceDraftRows.title == "New workspace")
        #expect(WorkspaceDraftRows.accessibilityLabel == "New workspace, draft")
    }
}

@Suite("Moving a draft to another project")
struct WorkspaceDraftMoveTests {
    private let quay = Repo(id: RepoID("quay"), name: "quay", path: "/tmp/quay", defaultBranch: "trunk")

    @Test("a project that already has a draft is gone to, and nothing moves")
    func goesToTheExistingDraft() {
        let draft = WorkspaceDraft(repoID: RepoID("harbour"), startingPoint: .newBranch(from: "main"), prompt: "x")
        #expect(WorkspaceDraftMove.decide(draft, to: quay, targetHasDraft: true) == .goTo(RepoID("quay")))
    }

    @Test("a draft moved to a project without one keeps its text and starts from that project's base")
    func movesAndResetsTheStart() {
        let branch = ExistingBranch(name: "bell", isLocal: true)
        let draft = WorkspaceDraft(
            repoID: RepoID("harbour"), startingPoint: .existingBranch(branch), prompt: "Ring it", attachmentKey: "k"
        )
        guard case .move(let moved) = WorkspaceDraftMove.decide(draft, to: quay, targetHasDraft: false) else {
            Issue.record("expected the draft to move")
            return
        }
        #expect(moved.repoID == RepoID("quay"))
        #expect(moved.startingPoint == .newBranch(from: "trunk"))
        #expect(moved.prompt == "Ring it")
        #expect(moved.attachmentKey == "k")
    }
}

@Suite("Which project a new workspace is for")
struct NewWorkspaceTargetTests {
    private let harbour = Repo(id: RepoID("harbour"), name: "harbour", path: "/tmp/harbour")
    private let quay = Repo(id: RepoID("quay"), name: "quay", path: "/tmp/quay")
    private var hidden: Repo {
        Repo(id: RepoID("attic"), name: "attic", path: "/tmp/attic", hidden: true)
    }

    private var repos: [Repo] { [hidden, harbour, quay] }

    @Test("a project asked for by name wins")
    func requestedWins() {
        #expect(NewWorkspaceTarget.project(
            requested: RepoID("quay"), selection: .home, workspaces: [], repos: repos
        )?.id == RepoID("quay"))
    }

    @Test("otherwise the project of the workspace in front")
    func selectedWorkspacesProject() {
        let workspace = Workspace(repoID: RepoID("quay"), name: "w", branch: "b", path: "/tmp/w", baseBranch: "main")
        #expect(NewWorkspaceTarget.project(
            requested: nil, selection: .workspace(workspace.id), workspaces: [workspace], repos: repos
        )?.id == RepoID("quay"))
    }

    @Test("otherwise the project of the draft in front")
    func draftsProject() {
        #expect(NewWorkspaceTarget.project(
            requested: nil, selection: .draft(RepoID("quay")), workspaces: [], repos: repos
        )?.id == RepoID("quay"))
    }

    @Test("from Home, the first project the sidebar shows, never a hidden one")
    func fromHome() {
        #expect(NewWorkspaceTarget.project(requested: nil, selection: .home, workspaces: [], repos: repos)?.id
            == RepoID("harbour"))
    }

    @Test("no projects, no target")
    func nothing() {
        #expect(NewWorkspaceTarget.project(requested: nil, selection: .home, workspaces: [], repos: []) == nil)
    }

    @Test("a project asked for that is gone falls back to the draft in front")
    func goneRequestFallsBack() {
        #expect(NewWorkspaceTarget.project(
            requested: RepoID("gone"), selection: .draft(RepoID("quay")), workspaces: [], repos: repos
        )?.id == RepoID("quay"))
    }
}
