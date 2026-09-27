import Testing
@testable import Core

@Suite("File tab mode")
struct FileTabModeTests {
    @Test("a previewable file offers all three, other files keep View and Edit")
    func choices() {
        #expect(FileTabMode.choices(hasPreview: true, canEdit: true) == [.preview, .source, .edit])
        #expect(FileTabMode.choices(hasPreview: false, canEdit: true) == [.source, .edit])
        #expect(FileTabMode.choices(hasPreview: true, canEdit: false) == [.preview, .source])
        #expect(FileTabMode.choices(hasPreview: false, canEdit: false) == [.source])
    }

    @Test("Source is called View when there is nothing rendered beside it")
    func titles() {
        #expect(FileTabMode.source.title(hasPreview: false) == "View")
        #expect(FileTabMode.source.title(hasPreview: true) == "Source")
        #expect(FileTabMode.preview.title(hasPreview: true) == "Preview")
        #expect(FileTabMode.edit.title(hasPreview: true) == "Edit")
    }

    @Test("leaving the editor returns to the preview it was opened from")
    func editRemembersPreview() {
        let editing = FileTabMode.edit.preferences(prefersPreview: true)
        let whileEditing = FileTabMode.current(
            prefersEditing: editing.prefersEditing, prefersPreview: editing.prefersPreview,
            hasPreview: true, canEdit: true
        )
        let afterEditing = FileTabMode.current(
            prefersEditing: false, prefersPreview: editing.prefersPreview, hasPreview: true, canEdit: true
        )
        #expect(whileEditing == .edit)
        #expect(afterEditing == .preview)
    }

    @Test("a file without a preview ignores the preference, and one that cannot be edited is never in Edit")
    func ignoredPreferences() {
        #expect(FileTabMode.current(prefersEditing: false, prefersPreview: true, hasPreview: false, canEdit: true) == .source)
        #expect(FileTabMode.current(prefersEditing: true, prefersPreview: true, hasPreview: true, canEdit: false) == .preview)
        let source = FileTabMode.source.preferences(prefersPreview: true)
        let preview = FileTabMode.preview.preferences(prefersPreview: false)
        #expect(source.prefersEditing == false)
        #expect(source.prefersPreview == false)
        #expect(preview.prefersEditing == false)
        #expect(preview.prefersPreview == true)
    }
}
