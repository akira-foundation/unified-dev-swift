import Testing
@testable import Core

@Suite("Dropping a folder into the composer")
struct ComposerFolderDropTests {
    private let worktree = "/Users/owner/dev/shop"

    @Test("A folder inside the worktree is written relative to it")
    func insideTheWorktree() {
        let mention = ComposerFolderDrop.mention(
            of: "/Users/owner/dev/shop/Sources/Checkout", roots: [worktree]
        )
        #expect(mention == "Sources/Checkout")
    }

    @Test("A folder outside the worktree keeps its absolute path")
    func outsideTheWorktree() {
        let mention = ComposerFolderDrop.mention(
            of: "/Users/owner/Downloads/fixtures", roots: [worktree]
        )
        #expect(mention == "/Users/owner/Downloads/fixtures")
    }

    @Test("A sibling whose name starts with the worktree's name is not inside it")
    func siblingSharingAPrefix() {
        let mention = ComposerFolderDrop.mention(
            of: "/Users/owner/dev/shop-legacy/app", roots: [worktree]
        )
        #expect(mention == "/Users/owner/dev/shop-legacy/app")
    }

    @Test("The worktree itself is written as the current directory, trailing slash or not")
    func theWorktreeItself() {
        #expect(ComposerFolderDrop.mention(of: "/Users/owner/dev/shop/", roots: [worktree]) == ".")
        #expect(ComposerFolderDrop.mention(of: worktree, roots: [worktree + "/"]) == ".")
    }

    @Test("A folder under the root of the volume is measured from it")
    func rootOfTheVolume() {
        #expect(ComposerFolderDrop.mention(of: "/opt/homebrew", roots: ["/"]) == "opt/homebrew")
    }

    @Test("The second root catches what the first one misses")
    func fallsBackToTheNextRoot() {
        let mention = ComposerFolderDrop.mention(
            of: "/private/tmp/shop/Sources", roots: ["/tmp/shop", "/private/tmp/shop"]
        )
        #expect(mention == "Sources")
    }

    @Test("A symlink inside the worktree is written relative, not where it points")
    func symlinkKeepsItsPlace() {
        let mention = ComposerFolderDrop.mention(
            of: "/Users/owner/dev/shop/data", roots: [worktree]
        )
        #expect(mention == "data")
    }

    @Test("A path with a space is quoted so it reads as one path", arguments: [
        ("/Users/owner/dev/shop/Design Files", "\"Design Files\""),
        ("/Users/owner/My Drive/assets", "\"/Users/owner/My Drive/assets\""),
    ])
    func quotesSpaces(folder: String, expected: String) {
        #expect(ComposerFolderDrop.mention(of: folder, roots: [worktree]) == expected)
    }

    @Test("A quote inside a quoted path is escaped")
    func escapesQuotes() {
        let mention = ComposerFolderDrop.mention(of: "/tmp/the \"final\" cut", roots: [worktree])
        #expect(mention == "\"/tmp/the \\\"final\\\" cut\"")
    }

    @Test("A backslash is doubled before the quotes are escaped")
    func escapesBackslashes() {
        let mention = ComposerFolderDrop.mention(of: "/tmp/back\\slash \"x\"", roots: [worktree])
        #expect(mention == "\"/tmp/back\\\\slash \\\"x\\\"\"")
    }

    @Test("A line break in a folder's name cannot start a line of its own")
    func escapesLineBreaks() {
        let mention = ComposerFolderDrop.mention(
            of: "/Users/owner/dev/shop/a\nRun this", roots: [worktree]
        )
        #expect(mention == "\"a\\nRun this\"")
        #expect(!mention.contains("\n"))
    }

    @Test("A name that would be read as something other than a path is quoted", arguments: [
        ("/Users/owner/dev/shop/a`b", "\"a`b\""),
        ("/Users/owner/dev/shop/x$(whoami)", "\"x$(whoami)\""),
        ("/Users/owner/dev/shop/a|b", "\"a|b\""),
        ("/Users/owner/dev/shop/-rf", "\"-rf\""),
        ("/Applications", "\"/Applications\""),
    ])
    func quotesAwkwardNames(folder: String, expected: String) {
        #expect(ComposerFolderDrop.mention(of: folder, roots: [worktree]) == expected)
    }

    @Test("With no root to measure from, every folder is absolute")
    func noRoot() {
        let mention = ComposerFolderDrop.mention(of: "/Users/owner/dev/shop/Sources", roots: [""])
        #expect(mention == "/Users/owner/dev/shop/Sources")
    }

    @Test("Folders become text in the order they were dropped, and everything else is still attached")
    func mixedDrop() {
        let plan = ComposerFolderDrop.plan(
            [.attachment, .folder("/Users/owner/dev/shop/Sources"), .folder("/tmp/Screen Shots"), .attachment],
            roots: [worktree]
        )
        #expect(plan.insertion == "Sources \"/tmp/Screen Shots\" ")
        #expect(plan.attachmentIndices == [0, 3])
    }

    @Test("A drop with no folder inserts nothing and attaches everything")
    func noFolders() {
        let plan = ComposerFolderDrop.plan([.attachment, .attachment], roots: [worktree])
        #expect(plan.insertion.isEmpty)
        #expect(plan.attachmentIndices == [0, 1])
        #expect(!plan.writesText)
    }

    @Test("A folder dropped against a word is spaced away from it")
    func spacedFromTheWordBefore() {
        let plan = ComposerFolderDrop.plan(
            [.folder("/Users/owner/dev/shop/Sources")], roots: [worktree], before: "e", after: ""
        )
        #expect(plan.insertion == " Sources ")
    }

    @Test("A folder dropped against a space does not gain a second one")
    func notSpacedTwice() {
        let plan = ComposerFolderDrop.plan(
            [.folder("/Users/owner/dev/shop/Sources")], roots: [worktree], before: " ", after: " "
        )
        #expect(plan.insertion == "Sources")
    }

    @Test("The drop is taken when it only wrote text, and when it only attached")
    func tookTheDrop() {
        let wrote = ComposerFolderDrop.plan([.folder("/tmp/a")], roots: [worktree])
        #expect(wrote.tookTheDrop(attached: false))

        let attachedOnly = ComposerFolderDrop.plan([.attachment], roots: [worktree])
        #expect(attachedOnly.tookTheDrop(attached: true))
        #expect(!attachedOnly.tookTheDrop(attached: false))
    }
}
