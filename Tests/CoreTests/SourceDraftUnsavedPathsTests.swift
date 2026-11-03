import Foundation
import Testing
@testable import Core

@Suite("Which drafts hold unsaved edits")
struct SourceDraftUnsavedPathsTests {
    private func draft(_ baseline: String, _ text: String) -> SourceDraft {
        SourceDraft(
            baseline: EditableFile(path: "/file.swift", text: baseline, modifiedAt: Date(), size: baseline.utf8.count),
            text: text
        )
    }

    @Test("Only the edited drafts are listed, in path order")
    func listsEditedDraftsInOrder() {
        let paths = SourceDraft.unsavedPaths(in: [
            "/b.swift": draft("one", "two"),
            "/c.swift": draft("same", "same"),
            "/a.swift": draft("one", "three"),
        ])
        #expect(paths == ["/a.swift", "/b.swift"])
    }
}
