import Testing
import Foundation
@testable import Core

@Suite("Sent turn")
struct SentTurnTests {
    @Test("the segments are the turn again", arguments: [
        "Merge #42.\n\n\(MergeInstructions.canonical)",
        "Open a pull request.\n\nFollow the instructions in `.unifieddev/scratch/pr-instructions.md`.",
        "Nothing injected here at all.",
        "",
    ])
    func segmentsRebuildTheTurn(turn: String) {
        #expect(SentTurn.segments(in: turn).map(\.text).joined() == turn)
    }

    @Test("a merge turn carrying a project's own words is still the turn again")
    func mergeWithProjectWordsRebuilds() {
        let turn = ProjectInstructions.turn(
            "Merge #42.", for: .merge, adding: .inline("We merge on Fridays only.")
        )
        #expect(SentTurn.segments(in: turn).map(\.text).joined() == turn)
    }

    @Test("Unified Dev's merge rules are one chip")
    func mergeRulesBecomeAChip() {
        let turn = "Merge #42.\n\n\(MergeInstructions.canonical)"

        #expect(SentTurn.segments(in: turn) == [
            .text("Merge #42.\n\n"),
            .instructions(
                InjectedInstruction(title: SentTurn.mergeTitle, body: MergeInstructions.canonical)
            ),
        ])
    }

    @Test("the pull request and conflict fallbacks are chips too")
    func writtenOutInstructionsBecomeChips() {
        let pullRequest = "Open a pull request.\n\n\(PullRequestInstructions.defaultMarkdown)"
        let conflicts = "Fix the conflicts.\n\n\(ConflictInstructions.defaultMarkdown)"

        #expect(SentTurn.segments(in: pullRequest).contains(
            .instructions(InjectedInstruction(
                title: SentTurn.pullRequestTitle, body: PullRequestInstructions.defaultMarkdown
            ))
        ))
        #expect(SentTurn.segments(in: conflicts).contains(
            .instructions(InjectedInstruction(
                title: SentTurn.conflictTitle, body: ConflictInstructions.defaultMarkdown
            ))
        ))
    }

    @Test("a retired default is still recognised")
    func retiredDefaultsAreRecognised() throws {
        let retired = try #require(PullRequestInstructions.retiredDefaults.first)
        let turn = "Open a pull request.\n\n\(retired)"

        #expect(SentTurn.segments(in: turn).contains(
            .instructions(
                InjectedInstruction(title: SentTurn.pullRequestTitle, body: retired)
            )
        ))
    }

    @Test("a project's own words are a chip and the sentence in front of them is not")
    func projectWordsBecomeAChip() {
        let words = "We merge on Fridays only.\nAsk Freek first."
        let turn = ProjectInstructions.turn("Merge #42.", for: .merge, adding: .inline(words))
        let segments = SentTurn.segments(in: turn)

        #expect(segments.contains(
            .instructions(InjectedInstruction(title: SentTurn.projectTitle, body: words))
        ))
        #expect(SentTurn.withoutInstructions(turn).hasSuffix(
            ProjectInstructions.inlineLead(for: .merge)
        ))
    }

    @Test("both blocks of a merge turn are chips, in the order they were read in")
    func mergeCarriesTwoBlocks() {
        let turn = ProjectInstructions.turn(
            "Merge #42.", for: .merge, adding: .inline("We merge on Fridays only.")
        )
        let titles = SentTurn.segments(in: turn).compactMap { segment -> String? in
            guard case .instructions(let block) = segment else { return nil }
            return block.title
        }

        #expect(titles == [SentTurn.mergeTitle, SentTurn.projectTitle])
    }

    @Test("Unified Dev's own instruction files carry the same titles as the blocks", arguments: [
        (PullRequestInstructions.scratchPath, SentTurn.pullRequestTitle),
        (PullRequestInstructions.projectPath, SentTurn.pullRequestTitle),
        (ConflictInstructions.scratchPath, SentTurn.conflictTitle),
        (ProjectInstructions.projectPath(for: .merge), SentTurn.projectTitle),
        (ProjectInstructions.scratchPath(for: .merge), SentTurn.projectTitle),
        (ProjectInstructions.projectPath(for: .fixConflicts), SentTurn.projectTitle),
        (ProjectInstructions.scratchPath(for: .fixConflicts), SentTurn.projectTitle),
    ])
    func instructionFilesAreTitled(path: String, title: String) {
        #expect(SentTurn.title(forFile: path) == title)
    }

    @Test("any other file keeps its own name", arguments: [
        "README.md",
        "docs/pr-instructions.md",
        ".unifieddev/setup.sh",
    ])
    func otherFilesAreNotTitled(path: String) {
        #expect(SentTurn.title(forFile: path) == nil)
    }

    @Test("a file named in the sentence is still a file")
    func filesAreStillFiles() {
        let turn = "Open a pull request.\n\nFollow the instructions in "
            + "`.unifieddev/scratch/pr-instructions.md`."

        #expect(SentTurn.segments(in: turn).contains(.file(".unifieddev/scratch/pr-instructions.md")))
    }

    @Test("a quoted line of the rules stays part of the sentence")
    func quotedRulesStayText() throws {
        let quoted = try #require(MergeInstructions.canonical.split(separator: "\n").first)
        let turn = "Why did you not \(quoted) like I asked?"

        #expect(SentTurn.segments(in: turn) == [.text(turn)])
    }

    @Test("a message with nothing injected is one run of words")
    func ordinaryTurnIsOneRun() {
        let turn = "Have a look at the merge instructions I wrote down somewhere."
        #expect(SentTurn.segments(in: turn) == [.text(turn)])
    }

    @Test("a summary drops the blocks and keeps the request")
    func summaryKeepsTheRequest() {
        let turn = "Merge #42.\n\n\(MergeInstructions.canonical)"
        #expect(SentTurn.withoutInstructions(turn) == "Merge #42.")
    }
}
