import Foundation
import Testing
@testable import Core

@Suite("Fix merge conflicts")
struct FixConflictsPromptTests {
    @Test("a conflicted pull request offers the fix rather than the merge")
    func conflictsOfferTheFix() {
        let status = conflicted().status

        #expect(status.remedy == .fixConflicts)
        #expect(status.text == "Merge conflicts")
        #expect(!status.canMerge)
        #expect(status.blockedReason != nil)
    }

    @Test("both of gh's words for a conflict reach the same button", arguments: [
        "CONFLICTING", "DIRTY", "conflicting",
    ])
    func bothVocabularies(mergeable: String) {
        #expect(conflicted(mergeable: mergeable).status.remedy == .fixConflicts)
    }

    @Test("local work does not move the conflicting state off the fix")
    func localWorkDoesNotWin() {
        let status = conflicted().status(local: LocalWork(modifiedFiles: 3, unpushedCommits: 1))

        #expect(status.remedy == .fixConflicts)
        #expect(status.text == "Merge conflicts")
    }

    @Test("nothing else in the strip gains the fix", arguments: [
        "MERGEABLE", "UNKNOWN", "",
    ])
    func onlyConflictsGetIt(mergeable: String) {
        #expect(conflicted(mergeable: mergeable).status.remedy == .merge)
    }

    @Test("the default prompt renders every fact it names")
    func rendersFully() {
        let definition = PromptRegistry.definition(for: .fixConflicts)
        let render = context().render(template: definition.defaultTemplate)

        #expect(render.unknown.isEmpty)
        #expect(render.missing.isEmpty)
        #expect(render.text.contains("#42"))
        #expect(render.text.contains("main"))
        #expect(render.text.contains("feature/glyphs"))
    }

    @Test("the message pushes the resolution and merges nothing")
    func pushesButDoesNotMerge() {
        let text = PromptRegistry.definition(for: .fixConflicts).defaultTemplate

        #expect(text.contains("push {{branch}}"))
        #expect(text.contains("Do not merge the pull request"))
        #expect(!text.contains("gh pr merge"))
    }

    @Test("the message says what was asked without the steps that say how")
    func messageIsTheRecordAndNotTheProcedure() {
        let render = context().render(
            template: PromptRegistry.definition(for: .fixConflicts).defaultTemplate
        )

        #expect(render.text.contains("#42"))
        #expect(render.text.contains("feature/glyphs"))
        #expect(render.text.contains("main"))
        #expect(!render.text.contains("--force-with-lease"))
        #expect(ConflictInstructions.defaultMarkdown.contains("--force-with-lease"))
        #expect(render.text.count < 500)
    }

    @Test("a workspace with no branch name never renders a guess")
    func missingBranchIsSaidRatherThanGuessed() {
        var facts = context()
        facts.branch = ""

        let render = facts.render(template: "{{branch}}")

        #expect(render.text == FixConflictsPromptContext.noBranch)
        #expect(render.text.contains("this worktree is already on"))
    }

    private func conflicted(mergeable: String = "CONFLICTING") -> PullRequest {
        PullRequest(
            number: 42, title: "Draw the glyphs", url: "https://example/42", state: "OPEN",
            isDraft: false, mergeable: mergeable, checks: .passing,
            checksSummary: "12 of 12 checks passed", reviewDecision: nil, branch: "feature/glyphs"
        )
    }

    private func context() -> FixConflictsPromptContext {
        FixConflictsPromptContext(
            workspaceName: "Glyphs",
            number: 42,
            branch: "feature/glyphs",
            baseBranch: "main"
        )
    }
}

@Suite("Conflict instructions", .tags(.git), .scratchDirectory)
struct ConflictInstructionsTests {
    @Test("the steps go into the shielded scratch folder and the sentence names them")
    func writesIntoTheScratchFolder() throws {
        let worktree = try emptyWorktree()

        let turn = ConflictInstructions.asking("Resolve #42.", in: worktree)

        #expect(WorktreeScratch.isShielded(ConflictInstructions.scratchPath))
        #expect(read(ConflictInstructions.scratchPath, in: worktree)
            == ConflictInstructions.defaultMarkdown)
        #expect(turn == """
        Resolve #42.

        Follow the instructions in `\(ConflictInstructions.scratchPath)`.
        """)
        #expect(AttachmentDraft.parse(turn).paths == [ConflictInstructions.scratchPath])
    }

    @Test("Unified Dev's file and the project's spilled settings are two different files")
    func doesNotCollideWithTheSpilledSettings() throws {
        let worktree = try emptyWorktree()

        let turn = ProjectInstructions.turn(
            ConflictInstructions.asking("Resolve #42.", in: worktree),
            for: .fixConflicts,
            adding: ProjectInstructions.resolve(
                .fixConflicts, in: worktree, stated: "Regenerate the lock file."
            )
        )

        let spilled = ProjectInstructions.scratchPath(for: .fixConflicts)
        #expect(ConflictInstructions.scratchPath != spilled)
        #expect(read(ConflictInstructions.scratchPath, in: worktree)
            == ConflictInstructions.defaultMarkdown)
        #expect(read(spilled, in: worktree) == "Regenerate the lock file.\n")
        #expect(AttachmentDraft.parse(turn).paths == [ConflictInstructions.scratchPath, spilled])
        #expect(turn.contains("where they disagree with anything above, they win"))
    }

    @Test("an agent told to commit the resolution cannot commit Unified Dev's file")
    func surviveAddEverything() async throws {
        let repo = try await TempRepo()
        defer { repo.cleanUp() }

        _ = ConflictInstructions.asking("Resolve #42.", in: repo.path)

        try await Shell.check("git", ["add", "-A"], cwd: repo.path)
        let staged = try await Shell.check(
            "git", ["diff", "--cached", "--name-only"], cwd: repo.path
        )
        #expect(staged.trimmed.isEmpty, "git staged \(staged.trimmed)")

        let status = try await Shell.check("git", ["status", "--porcelain"], cwd: repo.path)
        #expect(status.trimmed.isEmpty, "git reported \(status.trimmed)")
    }

    @Test("a second press replaces the copy the first one left")
    func isNeverStale() throws {
        let worktree = try emptyWorktree()

        _ = ConflictInstructions.asking("Resolve #42.", in: worktree, contents: "First.")
        _ = ConflictInstructions.asking("Resolve #42.", in: worktree, contents: "Second.")

        #expect(read(ConflictInstructions.scratchPath, in: worktree) == "Second.")
    }

    @Test("a worktree that cannot be written to still carries the steps")
    func fallsBackToTheMessage() {
        let turn = ConflictInstructions.asking("Resolve #42.", in: "/dev/null/nowhere")

        #expect(turn.hasPrefix("Resolve #42.\n\n"))
        #expect(turn.contains(ConflictInstructions.defaultMarkdown))
        #expect(!turn.contains(ConflictInstructions.scratchPath))
        #expect(ConflictInstructions.ensure(in: "/dev/null/nowhere") == nil)
    }

    @Test("the steps name no branch and no pull request")
    func nameNoFacts() {
        let text = ConflictInstructions.defaultMarkdown

        #expect(!text.contains(PromptTemplate.open))
        #expect(!text.contains("#42"))
        #expect(text.contains("the base branch"))
    }

    @Test("the steps keep the direction, the lease and the stop")
    func keepsWhatMatters() {
        let text = ConflictInstructions.defaultMarkdown

        #expect(text.contains("It goes into this branch and never the other way round."))
        #expect(text.contains("--force-with-lease"))
        #expect(text.contains("Do not push if you are not sure."))
        #expect(text.contains("Do not merge the pull request"))
    }

    @Test("the steps say which file a project writes instead of editing this one")
    func pointsAtTheProjectsOwnFile() {
        #expect(ConflictInstructions.defaultMarkdown
            .contains(ProjectInstructions.projectPath(for: .fixConflicts)))
    }

    private func emptyWorktree() throws -> String {
        let path = TestScratch.unique("worktree")
        try FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true)
        return path
    }

    private func read(_ relative: String, in worktree: String) -> String? {
        try? String(
            contentsOfFile: (worktree as NSString).appendingPathComponent(relative), encoding: .utf8
        )
    }
}
