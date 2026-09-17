import Foundation
import Testing
@testable import Core

@Suite("Attachments staged before the worktree existed", .scratchDirectory)
struct WorkspaceStartAttachmentsTests {
    private let file = ".unifieddev/attachments/9JVKW4/shot.png"

    private var draft: String {
        AttachmentDraft.inserting(file, into: "investigate this problem", at: 24).text
    }

    private func staging(holding paths: [String]) throws -> String {
        let root = TestScratch.unique("draft")
        for path in paths {
            let full = (root as NSString).appendingPathComponent(path)
            try FileManager.default.createDirectory(
                atPath: (full as NSString).deletingLastPathComponent,
                withIntermediateDirectories: true
            )
            try Data("png".utf8).write(to: URL(filePath: full))
        }
        return root
    }

    private func worktree() throws -> String {
        let path = TestScratch.unique("worktree")
        try FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true)
        return path
    }

    @Test("the file is in the worktree AND named in the first prompt")
    func fileCrossesAndIsNamed() throws {
        let staged = [file]
        let from = try staging(holding: staged)
        let into = try worktree()

        let handedOver = WorkspaceStartAttachments.handover(
            isChatWorkspace: true, draft: draft, name: ""
        )

        #expect(WorkspaceStartAttachments.spoken(handedOver, staged: staged)
            == "investigate this problem")

        let arrived = WorkspaceStartAttachments.adopt(staged, from: from, into: into)
        #expect(arrived == Set(staged))
        #expect(FileManager.default.fileExists(
            atPath: (into as NSString).appendingPathComponent(file)
        ))

        let opening = WorkspaceStartAttachments.opening(
            handedOver, staged: staged, arrived: arrived, isChatWorkspace: true
        )
        #expect(opening == "investigate this problem `\(file)`")
    }

    @Test("the id folder never reaches the name or the branch")
    func nameNeverSeesTheFile() {
        let handedOver = WorkspaceStartAttachments.handover(
            isChatWorkspace: true, draft: draft, name: ""
        )
        let spoken = WorkspaceStartAttachments.spoken(handedOver, staged: [file])
        #expect(!spoken.contains("9JVKW4"))
        #expect(Git.title(from: spoken) == "Investigate this problem")
    }

    @Test("a file that did not arrive is taken out of the sentence")
    func deadPathIsRemoved() throws {
        let staged = [file]
        let into = try worktree()
        let arrived = WorkspaceStartAttachments.adopt(
            staged, from: TestScratch.unique("empty"), into: into
        )
        #expect(arrived.isEmpty)

        let handedOver = WorkspaceStartAttachments.handover(
            isChatWorkspace: true, draft: draft, name: ""
        )
        let opening = WorkspaceStartAttachments.opening(
            handedOver, staged: staged, arrived: arrived, isChatWorkspace: true
        )
        #expect(opening == "investigate this problem")
    }

    @Test("a draft with no attachments is handed over as it was written")
    func plainDraftIsUntouched() {
        let opening = WorkspaceStartAttachments.opening(
            "investigate this problem", staged: [], arrived: [], isChatWorkspace: true
        )
        #expect(opening == "investigate this problem")
    }

    @Test("a terminal workspace carries the files and sends nothing")
    func terminalCarriesButSendsNothing() throws {
        let staged = [file]
        let from = try staging(holding: staged)
        let into = try worktree()

        let handedOver = WorkspaceStartAttachments.handover(
            isChatWorkspace: false, draft: draft, name: "  spacing  "
        )
        #expect(handedOver == "spacing")

        let arrived = WorkspaceStartAttachments.adopt(staged, from: from, into: into)
        #expect(FileManager.default.fileExists(
            atPath: (into as NSString).appendingPathComponent(file)
        ))
        #expect(WorkspaceStartAttachments.opening(
            handedOver, staged: staged, arrived: arrived, isChatWorkspace: false
        ) == nil)
    }

    @Test("the attachments folder arrives shielded from git")
    func adoptShieldsTheFolder() throws {
        let staged = [file]
        let from = try staging(holding: staged)
        let into = try worktree()

        WorkspaceStartAttachments.adopt(staged, from: from, into: into)

        let ignore = (into as NSString)
            .appendingPathComponent(WorktreeScratch.attachments + "/.gitignore")
        #expect(FileManager.default.fileExists(atPath: ignore))
    }
}
