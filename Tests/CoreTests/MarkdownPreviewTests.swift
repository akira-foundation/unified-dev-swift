import Testing
@testable import Core

@Suite("Offering a Markdown preview for a changed file")
struct MarkdownPreviewTests {
    @Test("a changed Markdown file is offered a preview")
    func markdownFile() {
        #expect(MarkdownPreview.isOffered(path: "docs/README.md", isBinary: false, change: .modified))
        #expect(MarkdownPreview.isOffered(path: "NOTES.markdown", isBinary: false, change: .untracked))
        #expect(MarkdownPreview.isOffered(path: "docs/README.md", isBinary: false, change: .added))
    }

    @Test("a file that is not Markdown is not offered a preview")
    func otherLanguages() {
        #expect(!MarkdownPreview.isOffered(path: "Sources/Checkout.swift", isBinary: false, change: .modified))
        #expect(!MarkdownPreview.isOffered(path: "notes.txt", isBinary: false, change: .modified))
    }

    @Test("there is nothing to preview in a deleted or binary file")
    func nothingToRead() {
        #expect(!MarkdownPreview.isOffered(path: "docs/README.md", isBinary: false, change: .deleted))
        #expect(!MarkdownPreview.isOffered(path: "docs/README.md", isBinary: true, change: .modified))
    }
}
