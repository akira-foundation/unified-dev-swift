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

    @Test("the preview button toggles an expanded file's preview")
    func togglesExpanded() {
        #expect(MarkdownPreview.isShown(afterToggling: false, collapsed: false))
        #expect(!MarkdownPreview.isShown(afterToggling: true, collapsed: false))
    }

    @Test("the preview button always shows the preview of a collapsed file it expands")
    func showsCollapsed() {
        #expect(MarkdownPreview.isShown(afterToggling: false, collapsed: true))
        #expect(MarkdownPreview.isShown(afterToggling: true, collapsed: true))
    }
}
