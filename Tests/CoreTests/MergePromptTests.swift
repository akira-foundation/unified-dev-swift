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

    @Test("a refusal is an answer, and nothing may be forced to get round it")
    func refusalIsAnAnswer() {
        let text = MergeInstructions.canonical

        #expect(text.contains("If GitHub refuses the merge, stop."))
        #expect(text.contains("do not force it"))
        #expect(text.contains("branch protection"))
        #expect(text.contains("Not `--admin`"))
        #expect(text.contains("Not `--auto`"))
    }

    @Test("nothing on this machine is touched")
    func nothingLocalIsTouched() {
        let text = MergeInstructions.canonical

        #expect(text.contains("Change nothing on this machine."))
        #expect(text.contains("Do not commit and do not push."))
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
