import Foundation
import Testing
@testable import Core

@Suite("Worktree scratch", .tags(.git), .scratchDirectory)
struct WorktreeScratchTests {
    @Test("a path inside a scratch folder is shielded and one beside it is not")
    func recognisesItsOwn() {
        #expect(WorktreeScratch.isShielded(".unifieddev/attachments"))
        #expect(WorktreeScratch.isShielded(".unifieddev/attachments/9JVKW4/IMG_4395.jpeg"))
        #expect(WorktreeScratch.isShielded(".unifieddev/scratch/pr-instructions.md"))

        #expect(WorktreeScratch.isShielded(".unifieddev") == false)
        #expect(WorktreeScratch.isShielded(".unifieddev/settings.toml") == false)
        #expect(WorktreeScratch.isShielded(".unifieddev/setup.sh") == false)
        #expect(WorktreeScratch.isShielded(".unifieddev/pr-instructions.md") == false)
        #expect(WorktreeScratch.isShielded(".unifieddev/attachments-of-mine.md") == false)
    }

    @Test("an agent told to commit everything cannot commit a scratch folder",
          arguments: WorktreeScratch.folders)
    func nothingInAScratchFolderCanBeStaged(folder: String) async throws {
        let repo = try await TempRepo()
        defer { repo.cleanUp() }

        WorktreeScratch.shield(folder, in: repo.path)
        try repo.write("\(folder)/whatever.txt", "Unified Dev wrote this and nobody asked for it.\n")
        try repo.write("\(folder)/nested/deeper.bin", "not a file anybody reviews\n")

        try await Shell.check("git", ["add", "-A"], cwd: repo.path)
        let staged = try await Shell.check(
            "git", ["diff", "--cached", "--name-only"], cwd: repo.path
        )
        #expect(staged.trimmed.isEmpty, "git staged \(staged.trimmed)")

        let status = try await Shell.check("git", ["status", "--porcelain"], cwd: repo.path)
        #expect(status.trimmed.isEmpty, "git reported \(status.trimmed)")
    }

    @Test("every folder on the list is Unified Dev's own corner of the repository")
    func foldersAreAllUnderUnifiedDev() {
        #expect(WorktreeScratch.folders.isEmpty == false)
        for folder in WorktreeScratch.folders {
            #expect(folder.hasPrefix(".unifieddev/"), "\(folder) is outside .unifieddev")
            #expect(WorktreeScratch.isShielded(folder))
        }
    }

    @Test("a scratch folder adds nothing to the repository, and settings still get their rules")
    func addsNothingButStillPreparesTheFolderLater() async throws {
        let repo = try await TempRepo()
        defer { repo.cleanUp() }

        WorktreeScratch.shield(WorktreeScratch.generated, in: repo.path)
        try repo.write("\(WorktreeScratch.generated)/pr-instructions.md", "Unified Dev's own\n")

        #expect(repo.exists(".unifieddev/.gitignore") == false)
        let untouched = try await Shell.check("git", ["status", "--porcelain"], cwd: repo.path)
        #expect(untouched.trimmed.isEmpty, "git reported \(untouched.trimmed)")

        SettingsWriter.prepareFolder(
            for: (repo.path as NSString).appendingPathComponent(".unifieddev/settings.toml"),
            repo: repo.path
        )
        try repo.write(".unifieddev/settings.local.toml", "token = \"do not commit me\"\n")
        try repo.write(".unifieddev/setup.local.sh", "#!/bin/zsh\necho mine\n")

        try await Shell.check("git", ["add", "-A"], cwd: repo.path)
        let staged = try await Shell.check(
            "git", ["diff", "--cached", "--name-only"], cwd: repo.path
        ).lines
        #expect(staged == [".unifieddev/.gitignore"])
    }

    @Test("an existing ignore file is never rewritten")
    func neverRewritesTheIgnoreFile() async throws {
        let repo = try await TempRepo()
        defer { repo.cleanUp() }

        try repo.write("\(WorktreeScratch.generated)/.gitignore", "*\n!keep.txt\n")
        WorktreeScratch.shield(WorktreeScratch.generated, in: repo.path)

        #expect(repo.read("\(WorktreeScratch.generated)/.gitignore") == "*\n!keep.txt\n")
    }
}
