import Testing
@testable import Core

@Suite("Dropping a folder into the composer")
struct ComposerFolderDropTests {
    private let worktree = "/Users/owner/dev/shop"

    @Test("A folder inside the worktree is written relative to it")
    func insideTheWorktree() {
        let mention = ComposerFolderDrop.mention(of: "/Users/owner/dev/shop/Sources/Checkout", worktree: worktree)
        #expect(mention == "Sources/Checkout")
    }

    @Test("A folder outside the worktree keeps its absolute path")
    func outsideTheWorktree() {
        let mention = ComposerFolderDrop.mention(of: "/Users/owner/Downloads/fixtures", worktree: worktree)
        #expect(mention == "/Users/owner/Downloads/fixtures")
    }

    @Test("A sibling whose name starts with the worktree's name is not inside it")
    func siblingSharingAPrefix() {
        let mention = ComposerFolderDrop.mention(of: "/Users/owner/dev/shop-legacy/app", worktree: worktree)
        #expect(mention == "/Users/owner/dev/shop-legacy/app")
    }

    @Test("The worktree itself is written as the current directory, trailing slash or not")
    func theWorktreeItself() {
        #expect(ComposerFolderDrop.mention(of: "/Users/owner/dev/shop/", worktree: worktree) == ".")
        #expect(ComposerFolderDrop.mention(of: "/Users/owner/dev/shop", worktree: worktree + "/") == ".")
    }

    @Test("A path with a space is quoted so it reads as one path", arguments: [
        ("/Users/owner/dev/shop/Design Files", "\"Design Files\""),
        ("/Users/owner/My Drive/assets", "\"/Users/owner/My Drive/assets\""),
    ])
    func quotesSpaces(folder: String, expected: String) {
        #expect(ComposerFolderDrop.mention(of: folder, worktree: worktree) == expected)
    }

    @Test("A quote inside a quoted path is escaped")
    func escapesQuotes() {
        let mention = ComposerFolderDrop.mention(of: "/tmp/the \"final\" cut", worktree: worktree)
        #expect(mention == "\"/tmp/the \\\"final\\\" cut\"")
    }

    @Test("With no worktree to measure from, every folder is absolute")
    func noWorktree() {
        let mention = ComposerFolderDrop.mention(of: "/Users/owner/dev/shop/Sources", worktree: "")
        #expect(mention == "/Users/owner/dev/shop/Sources")
    }

    @Test("Folders become text in the order they were dropped, and everything else is still attached")
    func mixedDrop() {
        let plan = ComposerFolderDrop.plan(
            [.attachment, .folder("/Users/owner/dev/shop/Sources"), .folder("/tmp/Screen Shots"), .attachment],
            worktree: worktree
        )
        #expect(plan.insertion == "Sources \"/tmp/Screen Shots\" ")
        #expect(plan.attachmentIndices == [0, 3])
    }

    @Test("A drop with no folder inserts nothing and attaches everything")
    func noFolders() {
        let plan = ComposerFolderDrop.plan([.attachment, .attachment], worktree: worktree)
        #expect(plan.insertion.isEmpty)
        #expect(plan.attachmentIndices == [0, 1])
    }
}
