import Foundation
import Testing
@testable import Core

@Suite("Project instructions", .tags(.git), .scratchDirectory)
struct ProjectInstructionsTests {
    @Test("a project with nothing to add gets a turn with nothing attached", arguments: ProjectInstructions.Subject.allCases)
    func silentByDefault(subject: ProjectInstructions.Subject) throws {
        let worktree = try emptyWorktree()

        let extra = ProjectInstructions.resolve(subject, in: worktree, stated: nil)
        let turn = ProjectInstructions.turn("Do the thing.", for: subject, adding: extra)

        #expect(extra == .nothing)
        #expect(!turn.contains("This project has its own instructions"))
        #expect(!turn.contains(WorktreeScratch.generated), "a turn names no file nobody wrote")
        #expect(!turn.contains(ProjectInstructions.projectPath(for: subject)))
        #expect(!FileManager.default.fileExists(
            atPath: (worktree as NSString).appendingPathComponent(WorktreeScratch.generated)
        ))
    }

    @Test("a file with nothing in it is nothing to say", arguments: ["", "   ", "\n\n  \n"])
    func emptyFileSaysNothing(contents: String) throws {
        let worktree = try emptyWorktree()
        try write(contents, to: ProjectInstructions.projectPath(for: .merge), in: worktree)

        #expect(ProjectInstructions.resolve(.merge, in: worktree, stated: nil) == .nothing)
    }

    @Test("an empty file does not outrank a settings value")
    func emptyFileDoesNotWin() throws {
        let worktree = try emptyWorktree()
        try write("\n", to: ProjectInstructions.projectPath(for: .merge), in: worktree)

        #expect(ProjectInstructions.resolve(.merge, in: worktree, stated: "Squash.")
            == .file(ProjectInstructions.scratchPath(for: .merge)))
    }

    @Test("the project's file is named in the turn, and nothing is written to say so")
    func fileIsNamed() throws {
        let worktree = try emptyWorktree()
        let path = ProjectInstructions.projectPath(for: .merge)
        try write("We merge on Fridays only.\n", to: path, in: worktree)

        let extra = ProjectInstructions.resolve(.merge, in: worktree, stated: nil)
        let turn = ProjectInstructions.turn("Merge #42.", for: .merge, adding: extra)

        #expect(extra == .file(path))
        #expect(turn.contains("`\(path)`"))
        #expect(turn.contains("where they disagree with anything above, they win"))
        #expect(read(path, in: worktree) == "We merge on Fridays only.\n")
        #expect(!FileManager.default.fileExists(
            atPath: (worktree as NSString)
                .appendingPathComponent(ProjectInstructions.scratchPath(for: .merge))
        ))
    }

    @Test("a settings value is spilled into the shielded folder and named from there")
    func settingsAreSpilled() throws {
        let worktree = try emptyWorktree()
        let scratch = ProjectInstructions.scratchPath(for: .fixConflicts)

        let extra = ProjectInstructions.resolve(
            .fixConflicts, in: worktree, stated: "Regenerate the lock file."
        )

        #expect(extra == .file(scratch))
        #expect(WorktreeScratch.isShielded(scratch))
        #expect(read(scratch, in: worktree) == "Regenerate the lock file.\n")
    }

    @Test("a settings value that changed replaces the copy from last time")
    func spilledCopyIsNotStale() throws {
        let worktree = try emptyWorktree()
        let scratch = ProjectInstructions.scratchPath(for: .merge)

        _ = ProjectInstructions.resolve(.merge, in: worktree, stated: "Squash.")
        _ = ProjectInstructions.resolve(.merge, in: worktree, stated: "Rebase.")

        #expect(read(scratch, in: worktree) == "Rebase.\n")
    }

    @Test("an agent told to commit everything cannot commit the spilled copy")
    func surviveAddEverything() async throws {
        let repo = try await TempRepo()
        defer { repo.cleanUp() }

        #expect(ProjectInstructions.resolve(.merge, in: repo.path, stated: "Squash.")
            == .file(ProjectInstructions.scratchPath(for: .merge)))

        try await Shell.check("git", ["add", "-A"], cwd: repo.path)
        let staged = try await Shell.check(
            "git", ["diff", "--cached", "--name-only"], cwd: repo.path
        )
        #expect(staged.trimmed.isEmpty, "git staged \(staged.trimmed)")
    }

    @Test("the project's file beats the settings field")
    func fileWins() throws {
        let worktree = try emptyWorktree()
        let path = ProjectInstructions.projectPath(for: .merge)
        try write("From the file.\n", to: path, in: worktree)

        let extra = ProjectInstructions.resolve(.merge, in: worktree, stated: "From the settings.")

        #expect(extra == .file(path))
        #expect(!FileManager.default.fileExists(
            atPath: (worktree as NSString)
                .appendingPathComponent(ProjectInstructions.scratchPath(for: .merge))
        ))
    }

    @Test("a worktree that cannot be written to still carries the project's words")
    func inlineWhenNothingCanBeWritten() {
        let extra = ProjectInstructions.resolve(
            .merge, in: "/dev/null/nowhere", stated: "We merge on Fridays only."
        )
        let turn = ProjectInstructions.turn("Merge #42.", for: .merge, adding: extra)

        #expect(extra == .inline("We merge on Fridays only."))
        #expect(turn.contains("We merge on Fridays only."))
        #expect(turn.contains(MergeInstructions.canonical))
    }

    @Test("the merge turn carries Unified Dev's rules whatever the project says")
    func mergeAlwaysCarriesTheRules() throws {
        let worktree = try emptyWorktree()

        let turn = ProjectInstructions.turn(
            "Merge #42.", for: .merge,
            adding: ProjectInstructions.resolve(.merge, in: worktree, stated: nil)
        )

        #expect(turn.hasPrefix("Merge #42.\n\n"))
        #expect(turn.contains(MergeInstructions.canonical))
    }

    @Test("the transcript can separate fixed merge rules from the visible request")
    func mergeRulesHaveACompactPresentation() throws {
        let worktree = try emptyWorktree()
        let turn = ProjectInstructions.turn(
            "Merge #42.", for: .merge,
            adding: ProjectInstructions.resolve(.merge, in: worktree, stated: nil)
        )

        let blocks = SentTurn.segments(in: turn).compactMap { segment -> InjectedInstruction? in
            guard case .instructions(let block) = segment else { return nil }
            return block
        }

        #expect(SentTurn.withoutInstructions(turn) == "Merge #42.")
        #expect(blocks == [
            InjectedInstruction(title: SentTurn.mergeTitle, body: MergeInstructions.canonical),
        ])
    }

    @Test("ordinary user text is never mistaken for a merge request")
    func ordinaryTextDoesNotBecomeMergeContext() {
        let text = "Please merge these two arrays."
        #expect(SentTurn.segments(in: text) == [.text(text)])
    }

    @Test("resolving a conflict adds no rules of Unified Dev's own here")
    func conflictsAddNothingOfOurs() {
        #expect(ProjectInstructions.canonical(for: .fixConflicts) == nil)
        #expect(ProjectInstructions.turn("Fix #42.", for: .fixConflicts, adding: .nothing)
            == "Fix #42.")
    }

    @Test("each subject asks for its own file, in its own words")
    func subjectsAreNotConfused() {
        let merge = ProjectInstructions.sentence(for: .merge, adding: .file("a.md")) ?? ""
        let conflicts = ProjectInstructions.sentence(
            for: .fixConflicts, adding: .file("b.md")
        ) ?? ""

        #expect(merge.contains("instructions for merging"))
        #expect(conflicts.contains("instructions for resolving merge conflicts"))
        #expect(ProjectInstructions.projectPath(for: .merge) == ".unifieddev/merge-instructions.md")
        #expect(ProjectInstructions.projectPath(for: .fixConflicts)
            == ".unifieddev/conflict-instructions.md")
    }

    @Test("the settings window is told about a file that outranks its field")
    func filesAreReportedToTheWindow() throws {
        let worktree = try emptyWorktree()
        try write("Squash.\n", to: ProjectInstructions.projectPath(for: .merge), in: worktree)

        let found = ProjectInstructions.files(in: worktree)

        #expect(found == [.merge: ProjectInstructions.projectPath(for: .merge)])
    }

    private func emptyWorktree() throws -> String {
        let path = TestScratch.unique("worktree")
        try FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true)
        return path
    }

    private func write(_ contents: String, to relative: String, in worktree: String) throws {
        let full = (worktree as NSString).appendingPathComponent(relative)
        try FileManager.default.createDirectory(
            atPath: (full as NSString).deletingLastPathComponent, withIntermediateDirectories: true
        )
        try contents.write(toFile: full, atomically: true, encoding: .utf8)
    }

    private func read(_ relative: String, in worktree: String) -> String? {
        try? String(
            contentsOfFile: (worktree as NSString).appendingPathComponent(relative), encoding: .utf8
        )
    }
}
