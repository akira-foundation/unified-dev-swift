import Foundation
import Testing
@testable import Core

@Suite("Merge prompt")
struct MergePromptTests {
    @Test("the default prompt renders every fact the instructions cannot know")
    func rendersFully() {
        let definition = PromptRegistry.definition(for: .mergePullRequest)
        let render = context().render(template: definition.defaultTemplate)

        #expect(render.unknown.isEmpty)
        #expect(render.missing.isEmpty)
        #expect(render.text.contains("#42"))
        #expect(render.text.contains("main"))
        #expect(render.text.contains("feature/glyphs"))
        #expect(render.text.contains("squash merge"))
        #expect(render.text.contains("--squash"))
    }

    @Test("every method has a phrase and the flag that performs it", arguments: [
        (method: GitHub.MergeMethod.squash, phrase: "squash merge", flag: "--squash"),
        (method: .merge, phrase: "merge commit", flag: "--merge"),
        (method: .rebase, phrase: "rebase merge", flag: "--rebase"),
    ])
    func methodWords(method: GitHub.MergeMethod, phrase: String, flag: String) {
        #expect(method.phrase == phrase)
        #expect(method.flag == flag)
    }

    @Test("a pull request with no branch name never renders a guess")
    func missingBranchIsSaidRatherThanGuessed() {
        var facts = context()
        facts.branch = ""

        let render = facts.render(template: "{{branch}}")

        #expect(render.text == MergePromptContext.noBranch)
        #expect(render.text.contains("do not guess"))
        #expect(render.text.contains("leave the branch on the server alone"))
    }

    @Test("a pull request with no title still reads as a sentence")
    func missingTitleIsSaid() {
        var facts = context()
        facts.title = ""

        #expect(facts.render(template: "{{title}}").text == MergePromptContext.noTitle)
    }

    @Test("the prompt names the base the pull request targets, not the workspace's")
    func mergesIntoThePullRequestsBase() {
        let workspace = Workspace(
            repoID: .new(), name: "Unified Dev", branch: "chore/release-setup",
            path: "/tmp/unified-dev", baseBranch: "main"
        )
        let pullRequest = PullRequest(
            number: 6, title: "Release setup", url: "https://example/6", state: "OPEN",
            branch: "chore/release-setup", baseBranch: "develop"
        )

        let render = MergePromptContext(workspace: workspace, pullRequest: pullRequest, method: .merge)
            .render(template: PromptRegistry.definition(for: .mergePullRequest).defaultTemplate)

        #expect(render.text.contains("into develop"))
        #expect(!render.text.contains("into main"))
    }

    @Test("gh is asked for the base, with or without the checks")
    func asksGHForTheBase() {
        #expect(GitHub.fields.split(separator: ",").contains("baseRefName"))
        #expect(GitHub.fieldsWithoutChecks.split(separator: ",").contains("baseRefName"))
    }

    private func context() -> MergePromptContext {
        MergePromptContext(
            workspaceName: "Unified Dev",
            number: 42,
            title: "Better glyphs",
            branch: "feature/glyphs",
            baseBranch: "main",
            method: .squash
        )
    }
}

@Suite("Merge instructions")
struct MergeInstructionsTests {
    @Test("the instructions name no pull request, branch or method")
    func namesNothingWorkspaceSpecific() {
        let text = MergeInstructions.canonical

        #expect(!text.contains("gh pr merge 42"))
        #expect(text.contains("<number>"))
        #expect(text.contains("<branch>"))
        #expect(text.contains("the message names"))
    }

    @Test("the merge and the branch deletion are separate steps, in that order")
    func twoStepsNotOne() {
        let text = MergeInstructions.canonical

        #expect(text.contains("gh pr merge <number> <method flag>"))
        #expect(text.contains("git push --delete -- origin refs/heads/<branch>"))
        #expect(text.contains("Not `--delete-branch`"))
        #expect(text.contains("Only once the merge has actually succeeded"))
        guard let merge = text.range(of: "gh pr merge"),
              let delete = text.range(of: "git push --delete")
        else {
            Issue.record("the two commands are not both in the instructions")
            return
        }
        #expect(merge.lowerBound < delete.lowerBound)
    }

    private var flattened: String {
        MergeInstructions.canonical.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    @Test("a refusal is read from the pull request's state, not from its wording")
    func refusalIsClassifiedByState() {
        let text = flattened

        #expect(text.contains("not from the wording of the refusal"))
        #expect(text.contains("`gh pr view <number> --json mergeStateStatus,mergeable,isCrossRepository`"))
        #expect(text.contains("`gh pr checks <number>`. While either field reads `UNKNOWN`"))
        #expect(!text.contains("--required"))
        #expect(text.contains("Before changing anything, read the sha of the branch on the server with `git ls-remote origin refs/heads/<branch>`. It has to be this worktree's `HEAD`; if it is not, stop as the list below says."))
        #expect(text.contains("While either field reads `UNKNOWN`, GitHub is still working it out: wait a few seconds and read it again."))
    }

    @Test("a conflict or a failed check is resolved and the merge tried again")
    func resolvableRefusalsAreResolved() {
        let text = flattened

        #expect(text.contains("Conflicting (`mergeable` is `CONFLICTING`) or behind the base"))
        #expect(text.contains("A check failed: read its log with `gh run view <run id> --log-failed`"))
        #expect(text.contains("Otherwise merge it in, unless the project's own conventions say to rebase."))
        #expect(text.contains("Work through every conflicted file keeping what both sides changed, and run whatever this project uses to check itself."))
        #expect(text.contains("the run id being the number after `/runs/` in the check's link"))
        #expect(text.contains("A check run outside GitHub Actions has no such log: stop and say so."))
        #expect(text.contains("A check is still running: wait for it, which is not a round."))
        #expect(text.contains("Wait until `gh pr view <number> --json headRefOid` names the sha you pushed, so the checks you read are this commit's and not the last one's."))
        #expect(text.contains("push it to this branch and no other"))
        #expect(text.contains("wait for every check to finish with `gh pr checks <number> --watch`, required or not, and run the same `gh pr merge` again only once they are all green."))
        #expect(!text.contains("nothing to wait for"))
        #expect(text.contains("If none appear within five minutes, the repository runs none."))
        #expect(text.contains("A check that fails while you wait starts the next round, not a stop."))
        #expect(!text.contains("If GitHub refuses the merge, stop."))
    }

    @Test("a rebase merge is answered with a rebase, so the conflict does not come back")
    func rebaseMethodRebases() {
        #expect(flattened.contains("With `--rebase` as the method, rebase onto it"))
    }

    @Test("a rewritten branch is pushed with a lease on the sha it had, never forced")
    func forcePushIsLeased() {
        let text = flattened

        #expect(text.contains("`--force-with-lease=<branch>:<sha>`"))
        #expect(text.contains("naming the last sha you pushed, or before your first push the sha you checked at the start, never one a later fetch brought in"))
        #expect(text.contains("Never a bare `--force`."))
    }

    @Test("the server's sha is read before anything is changed or pushed")
    func serverShaIsReadFirst() {
        let text = flattened
        guard let read = text.range(of: "git ls-remote origin refs/heads/<branch>"),
              let commit = text.range(of: "Commit the fix")
        else {
            Issue.record("the read or the commit step is missing")
            return
        }
        #expect(read.lowerBound < commit.lowerBound)
    }

    @Test("the retries stop after three rounds")
    func retriesAreBounded() {
        let text = flattened

        #expect(text.contains("**Three rounds at most.** A round is one fix, one push and one merge attempt."))
        #expect(text.contains("If the third is refused too, stop and say what GitHub said each time."))
        #expect(text.contains("**Thirty minutes of waiting at most**, counting every wait above together: for `UNKNOWN`, for a check still running, and after each push. Past it, stop and say what never finished."))
    }

    @Test("a fix never weakens the checks to turn them green")
    func checksAreNotWeakened() {
        let text = flattened

        #expect(text.contains("**A fix never weakens what checks the branch.**"))
        #expect(text.contains("Do not edit a workflow, skip, delete or loosen a test, or relax a lint rule to turn a check green. If that is the only way, stop and say so."))
    }

    @Test("any other refusal is an answer, and no repository setting may be changed for it")
    func otherRefusalsAreAnswers() {
        let text = flattened

        #expect(text.contains("**Any other refusal, stop.**"))
        #expect(text.contains("Do not force it, and do not change a branch protection rule, a required check, a review or any other repository setting to get round it."))
        #expect(text.contains("Not `--admin`"))
        #expect(text.contains("Not `--auto`"))
    }

    @Test("a fork, unpublished work or a guess stops the resolution")
    func doubtStopsTheResolution() {
        let text = flattened

        #expect(text.contains("**Stop rather than guess.** Resolve nothing"))
        #expect(text.contains("the pull request comes from a fork (`isCrossRepository` is true)"))
        #expect(text.contains("the message does not name the branch, because a push needs one"))
        #expect(text.contains("at the start, or after any fetch in any round, the branch on the server is not where this worktree last saw it, because a rewritten push would drop what somebody else put there"))
        #expect(text.contains("this worktree already held work GitHub has not got before you started, uncommitted or committed and not pushed, because a push would carry it out with the fix"))
        #expect(text.contains("a conflict genuinely could be resolved either way, or a check fails for a reason neither branch explains"))
        #expect(text.contains("Commit and push nothing but the resolution of a refusal and the branch deletion above."))
    }

    @Test("only a step outside the resolution stops on failure")
    func failureClauseLeavesTheRoundsAlone() {
        let text = flattened

        #expect(text.contains("If any other step fails, stop"))
    }

    @Test("the report says what was fixed and in how many rounds")
    func reportsTheRounds() {
        #expect(flattened.contains("what you fixed on the way and in how many rounds"))
    }

    @Test("the worktree stays where it is")
    func theWorktreeStays() {
        let text = flattened

        #expect(text.contains("Leave the worktree where it is."))
        #expect(text.contains("Do not delete the local branch, do not remove or move the worktree, and do not check out anything else."))
        #expect(text.contains("If the merge went through with such work still here, say in one line that it was left behind."))
    }

    @Test("the editable template holds none of the rules")
    func theTemplateHoldsNoRules() {
        let template = PromptRegistry.definition(for: .mergePullRequest).defaultTemplate

        #expect(!template.contains("--admin"))
        #expect(!template.contains("git push --delete"))
        #expect(!MergeInstructions.canonical.contains("{{"))
    }
}

@Suite("Merge gating")
struct MergeGatingTests {
    @Test("a state GitHub might still merge keeps the button live", arguments: [
        "FAILING", "PENDING", "NONE",
    ])
    func permissiveWhereGitHubDecides(checks: String) throws {
        #expect(try pullRequest(state: "OPEN", checks: checks).status.canMerge)
    }

    @Test("work on this disk does not disable the button")
    func localWorkDoesNotBlock() throws {
        let status = try pullRequest(state: "OPEN", checks: "NONE")
            .status(local: LocalWork(modifiedFiles: 3))

        #expect(status.canMerge)
        #expect(status.blockedReason == nil)
    }

    @Test("a state with nothing left to ask GitHub is refused, with a reason", arguments: [
        "MERGED", "CLOSED",
    ])
    func refusesWhatIsFinished(state: String) throws {
        let status = try pullRequest(state: state, checks: "NONE").status

        #expect(!status.canMerge)
        #expect(status.blockedReason != nil)
    }

    private func pullRequest(state: String, checks: String) throws -> PullRequest {
        let run: String
        switch checks {
        case "FAILING":
            run = #"[{"__typename":"CheckRun","name":"a","status":"COMPLETED","conclusion":"FAILURE","isRequired":true}]"#
        case "PENDING":
            run = #"[{"__typename":"CheckRun","name":"a","status":"IN_PROGRESS","isRequired":true}]"#
        default:
            run = "[]"
        }
        let json = """
        {"number":42,"title":"Better glyphs","url":"https://github.com/a/b/pull/42",\
        "state":"\(state)","isDraft":false,"headRefName":"feature/glyphs",\
        "statusCheckRollup":\(run)}
        """
        return try GitHub.decodePullRequest(from: Data(json.utf8))
    }
}
