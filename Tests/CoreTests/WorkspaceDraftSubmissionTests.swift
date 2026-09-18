import Foundation
import Testing
@testable import Core

@Suite("A draft handed to the workspace start")
struct WorkspaceDraftSubmissionTests {
    private func draft(
        _ point: WorkspaceStartingPoint, prompt: String = "  Light the lamp \n", controls: WorkspaceDraftControls? = nil
    ) -> WorkspaceDraft {
        WorkspaceDraft(repoID: RepoID("harbour"), startingPoint: point, prompt: prompt, controls: controls)
    }

    @Test("a new branch cuts from its base, with the text trimmed and no checkout")
    func newBranch() {
        let submission = WorkspaceDraftSubmission(draft: draft(.newBranch(from: "develop")), defaultBranch: "main")
        #expect(submission.prompt == "Light the lamp")
        #expect(submission.baseBranch == "develop")
        #expect(submission.checkout == nil)
        #expect(submission.mode == .chat)
    }

    @Test("an existing branch opens it, over the project's default base")
    func existingBranch() {
        let bell = ExistingBranch(name: "bell", isLocal: true)
        let submission = WorkspaceDraftSubmission(draft: draft(.existingBranch(bell)), defaultBranch: "main")
        #expect(submission.checkout == .branch(bell))
        #expect(submission.baseBranch == "main")
    }

    @Test("a pull request opens it, over the branch it merges into")
    func pullRequest() {
        let request = PullRequestListing(number: 13, title: "t", headRefName: "paint", baseRefName: "release")
        let submission = WorkspaceDraftSubmission(draft: draft(.pullRequest(request)), defaultBranch: "main")
        #expect(submission.checkout == .pullRequest(request))
        #expect(submission.baseBranch == "release")
    }

    @Test("an empty prompt stays empty, and the workspace still starts")
    func emptyPrompt() {
        let submission = WorkspaceDraftSubmission(
            draft: draft(.newBranch(from: "main"), prompt: " \n"), defaultBranch: "main"
        )
        #expect(submission.prompt.isEmpty)
    }

    @Test("the CLI switch and the agent choose the way the chat opens")
    func cliChat() {
        let kept = WorkspaceDraftControls(ComposerControls(agentKind: .claudeCode), usesCLIChat: true)
        let submission = WorkspaceDraftSubmission(draft: draft(.newBranch(from: "main"), controls: kept), defaultBranch: "main")
        #expect(submission.mode == .claudeCLI)
    }

    @Test("the kept controls win over the defaults, and no kept controls leave the defaults")
    func controlsOverDefaults() {
        let kept = WorkspaceDraftControls(ComposerControls(model: "gpt-5", agentKind: .codex), usesCLIChat: false)
        let defaults = ComposerControls(model: "opus")
        let chosen = WorkspaceDraftSubmission(draft: draft(.newBranch(from: "main"), controls: kept), defaultBranch: "main")
        let bare = WorkspaceDraftSubmission(draft: draft(.newBranch(from: "main")), defaultBranch: "main")
        #expect(chosen.controls(over: defaults).model == "gpt-5")
        #expect(bare.controls(over: defaults).model == "opus")
    }
}
