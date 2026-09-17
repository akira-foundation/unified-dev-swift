import Testing
@testable import Core

@Suite("File tree filter")
struct FileTreeFilterTests {
    private let index = FileTreeNode.index([
        "README.md",
        "app/Http/Controllers/UserController.php",
        "app/Http/Kernel.php",
        "app/models/User.php",
        "app/models/Invoice.php",
        "tests/Feature/UserTest.php",
    ])

    @Test func revealingAFileKeepsOtherExpandedFolders() throws {
        let ancestors = try #require(FileTreeNode.ancestors(of: "app/Http/Controllers/UserController.php", in: index))
        let restored: Set<String> = ["tests", "tests/Feature"]
        let expanded = restored.union(ancestors)
        #expect(ancestors == ["app", "app/Http", "app/Http/Controllers"])
        let paths = FileTreeRowItem.flatten(children: index, expanded: expanded).map(\.node.path)
        #expect(paths.contains("app/Http/Controllers/UserController.php"))
        #expect(paths.contains("tests/Feature/UserTest.php"))
        #expect(FileTreeNode.ancestors(of: "README.md", in: index) == [])
        #expect(FileTreeNode.ancestors(of: "missing.php", in: index) == nil)
        #expect(FileTreeNode.ancestors(of: "app/Http", in: index) == nil)
        #expect(FileTreeNode.ancestors(of: "/app/Http/Kernel.php", in: index) == nil)
        #expect(FileTreeNode.ancestors(of: "../app/Http/Kernel.php", in: index) == nil)
    }

    private func rows(_ outcome: FileTreeFilter.Outcome) -> [String] {
        FileTreeRowItem.flatten(children: outcome.children, expanded: outcome.open)
            .map(\.node.path)
    }

    @Test("An empty needle is no filter at all, which is not the same answer as no matches")
    func emptyNeedleChangesNothing() {
        #expect(FileTreeFilter.apply(to: index, needle: "") == nil)
        #expect(FileTreeFilter.apply(to: index, needle: FileNeedle.canonical("   ")) == nil)
    }

    @Test("Whitespace is trimmed and case folded before anything is asked of the needle")
    func needleIsCanonical() {
        #expect(FileNeedle.canonical("  UserCon ") == "usercon")
    }

    @Test("A folder survives because a file inside it matched, and opens to show it")
    func ancestorSurvivesForItsDescendant() throws {
        let outcome = try #require(FileTreeFilter.apply(to: index, needle: "usercon"))

        #expect(rows(outcome) == [
            "app",
            "app/Http",
            "app/Http/Controllers",
            "app/Http/Controllers/UserController.php",
        ])
        #expect(outcome.open == ["app", "app/Http", "app/Http/Controllers"])
        #expect(outcome.isEmpty == false)
    }

    @Test("A folder holding nothing that matched is gone, sibling files included")
    func siblingsAreNotDraggedIn() throws {
        let outcome = try #require(FileTreeFilter.apply(to: index, needle: "usercon"))
        let paths = rows(outcome)

        #expect(paths.contains("app/models") == false)
        #expect(paths.contains("app/Http/Kernel.php") == false)
        #expect(paths.contains("README.md") == false)
    }

    @Test("A folder that matched by its own name shows its children")
    func selfMatchedFolderKeepsItsChildren() throws {
        let outcome = try #require(FileTreeFilter.apply(to: index, needle: "models"))

        #expect(rows(outcome) == [
            "app",
            "app/models",
            "app/models/Invoice.php",
            "app/models/User.php",
        ])
        #expect(outcome.open.contains("app/models"))
    }

    @Test("A matched folder opens one level, not its whole subtree")
    func selfMatchedFolderOpensOneLevel() throws {
        let outcome = try #require(FileTreeFilter.apply(to: index, needle: "http"))

        #expect(rows(outcome) == [
            "app",
            "app/Http",
            "app/Http/Controllers",
            "app/Http/Kernel.php",
        ])
        #expect(outcome.open.contains("app/Http/Controllers") == false)
    }

    @Test("Matching is case insensitive and by subsequence, not by prefix")
    func matchingIsForgiving() throws {
        for needle in ["usercon", "USERCON", "uc.php", "controller"] {
            let outcome = try #require(FileTreeFilter.apply(to: index, needle: needle.lowercased()))
            #expect(
                rows(outcome).contains("app/Http/Controllers/UserController.php"),
                "\(needle) should find UserController.php"
            )
        }
    }

    @Test("A needle with a slash in it is matched against the path rather than the name")
    func slashMatchesThePath() throws {
        let outcome = try #require(FileTreeFilter.apply(to: index, needle: "app/mod"))
        let paths = rows(outcome)

        #expect(paths.contains("app/models/User.php"))
        #expect(paths.contains("app/models/Invoice.php"))
        #expect(paths.contains("tests/Feature/UserTest.php") == false)
    }

    @Test("A needle nothing answers says so, rather than answering with the whole tree")
    func nothingMatches() throws {
        let outcome = try #require(FileTreeFilter.apply(to: index, needle: "zzqq"))

        #expect(outcome.isEmpty)
        #expect(rows(outcome).isEmpty)
        #expect(outcome.open.isEmpty)
    }

    @Test("A directory nothing survived in is left out rather than kept as an empty entry")
    func prunedIndexStaysSmall() throws {
        let outcome = try #require(FileTreeFilter.apply(to: index, needle: "usercon"))

        #expect(outcome.children.keys.sorted() == ["", "app", "app/Http", "app/Http/Controllers"])
    }

    @Test("Clearing the filter puts every folder back where the reader had it")
    func expansionSurvivesAFilter() throws {
        let reader: Set<String> = ["app", "app/models"]
        let before = FileTreeRowItem.flatten(children: index, expanded: reader).map(\.node.path)

        let outcome = try #require(FileTreeFilter.apply(to: index, needle: "usercon"))
        #expect(outcome.open.contains("app/Http/Controllers"))
        #expect(rows(outcome) != before)

        #expect(FileTreeFilter.apply(to: index, needle: "") == nil)
        let after = FileTreeRowItem.flatten(children: index, expanded: reader).map(\.node.path)
        #expect(after == before)
    }
}
