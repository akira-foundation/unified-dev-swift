import Testing
import Foundation
@testable import Core

@Suite("Settings document, a table already written another way")
struct SettingsDocumentTablesTests {
    @Test("a key added to an inline table opens it into a table instead of defining it twice")
    func inlineTableIsOpened() throws {
        var document = SettingsDocument(text: """
        name = "ada"
        git = { archive_on_merge = true }
        """)

        document.set(.boolean(true), at: ["git", "delete_branch_on_archive"])

        #expect(document.text == """
        name = "ada"

        [git]
        archive_on_merge = true
        delete_branch_on_archive = true
        """)
    }

    @Test("a key already inside an inline table is changed there, not written a second time")
    func inlineKeyIsReplaced() {
        var document = SettingsDocument(text: "git = { archive_on_merge = true, delete_branch_on_archive = false } # mine\n")

        document.set(.boolean(true), at: ["git", "delete_branch_on_archive"])

        #expect(document.text == """
        # mine
        [git]
        archive_on_merge = true
        delete_branch_on_archive = true

        """)
    }

    @Test("an inline table holding a nested table keeps its nesting")
    func nestedInlineTableIsKept() {
        var document = SettingsDocument(text: #"git = { remote = { name = "origin, upstream" } }"#)

        document.set(.boolean(true), at: ["git", "archive_on_merge"])

        #expect(document.text == """
        [git]
        remote = { name = "origin, upstream" }
        archive_on_merge = true
        """)
    }

    @Test("dotted keys that already define the table move into it rather than meet a second definition")
    func dottedKeysMoveIntoTheTable() {
        var document = SettingsDocument(text: """
        git.archive_on_merge = true
        other = 1
        """)

        document.set(.boolean(false), at: ["git", "delete_branch_on_archive"])

        #expect(document.text == """
        other = 1

        [git]
        archive_on_merge = true
        delete_branch_on_archive = false
        """)
    }

    @Test("a dotted key that is already the one being set is changed where it stands")
    func dottedKeyIsReplacedInPlace() {
        var document = SettingsDocument(text: "git.delete_branch_on_archive = false\n")

        document.set(.boolean(true), at: ["git", "delete_branch_on_archive"])

        #expect(document.text == "git.delete_branch_on_archive = true\n")
    }

    @Test("a sub-table's own keys are not taken into its parent")
    func subTableKeysStay() {
        var document = SettingsDocument(text: """
        [git.remote]
        name = "origin"
        """)

        document.set(.boolean(true), at: ["git", "archive_on_merge"])

        #expect(document.text == """
        [git.remote]
        name = "origin"

        [git]
        archive_on_merge = true
        """)
    }

    @Test("the global settings file reads back what was written over an inline table")
    func globalSettingsReadBack() throws {
        let file = TestScratch.unique("global-settings") + "/settings.toml"
        try FileManager.default.createDirectory(
            atPath: (file as NSString).deletingLastPathComponent, withIntermediateDirectories: true
        )
        try "git = { archive_on_merge = true }\n".write(toFile: file, atomically: true, encoding: .utf8)

        try GlobalWorkspaceSettings.setDeleteBranchOnArchive(true, in: file)

        let written = try String(contentsOfFile: file, encoding: .utf8)
        #expect(written == "[git]\narchive_on_merge = true\ndelete_branch_on_archive = true\n")
        #expect(GlobalWorkspaceSettings.deleteBranchOnArchive(paths: [file]))
        #expect(GlobalWorkspaceSettings.archiveOnMerge(paths: [file]))
    }
}
