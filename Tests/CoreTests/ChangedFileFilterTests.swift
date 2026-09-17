import Testing
@testable import Core

@Suite("Changed file filter")
struct ChangedFileFilterTests {
    private let files = [
        ChangedFile(path: "README.md", change: .modified),
        ChangedFile(path: "app/Http/Controllers/UserController.php", change: .added),
        ChangedFile(path: "app/Http/Kernel.php", change: .modified),
        ChangedFile(path: "database/migrations/2024_create_users_table.php", change: .added),
        ChangedFile(path: "tests/Feature/UserTest.php", change: .modified),
    ]

    private func paths(_ files: [ChangedFile]) -> [String] {
        files.map(\.path)
    }

    @Test("An empty needle is no filter at all, which is not the same answer as no matches")
    func emptyNeedleChangesNothing() {
        #expect(ChangedFileFilter.apply(to: files, needle: "") == nil)
        #expect(ChangedFileFilter.apply(to: files, needle: FileNeedle.canonical("  ")) == nil)
    }

    @Test("A file is found by its name, case insensitively and by subsequence")
    func matchesByName() throws {
        for needle in ["usercontroller", "USERCON", "uc.php"] {
            let kept = try #require(
                ChangedFileFilter.apply(to: files, needle: FileNeedle.canonical(needle))
            )
            #expect(
                paths(kept).contains("app/Http/Controllers/UserController.php"),
                "\(needle) should find UserController.php"
            )
        }
    }

    @Test("A file is found by a folder it lives in, which is the whole reason this matches paths")
    func matchesByFolder() throws {
        let kept = try #require(ChangedFileFilter.apply(to: files, needle: "migrations"))

        #expect(paths(kept) == ["database/migrations/2024_create_users_table.php"])
    }

    @Test("A path fragment matches the path it is a fragment of")
    func matchesByPathFragment() throws {
        let kept = try #require(ChangedFileFilter.apply(to: files, needle: "app/http"))

        #expect(paths(kept) == [
            "app/Http/Controllers/UserController.php",
            "app/Http/Kernel.php",
        ])
    }

    @Test("The diff's own order is kept, because the tree is rebuilt from what comes back")
    func orderIsPreserved() throws {
        let kept = try #require(ChangedFileFilter.apply(to: files, needle: "php"))

        #expect(paths(kept) == paths(files.filter { $0.path.hasSuffix(".php") }))
    }

    @Test("A needle nothing answers comes back empty rather than as the whole diff")
    func nothingMatches() throws {
        let kept = try #require(ChangedFileFilter.apply(to: files, needle: "zzqq"))

        #expect(kept.isEmpty)
    }

    @Test("The status letter is not searchable, and a single letter is not a status filter")
    func statusIsNotSearchable() throws {
        let added = try #require(ChangedFileFilter.apply(to: files, needle: "a"))
        #expect(paths(added).contains("app/Http/Kernel.php"))
        #expect(added.allSatisfy { $0.change == .added } == false)
    }

    @Test("A chain that stops branching under a filter is said on one row again")
    func chainsRecollapse() throws {
        let whole = ChangedFileTree.build(from: files)
        #expect(whole.first?.name == "app / Http")

        let kept = try #require(ChangedFileFilter.apply(to: files, needle: "usercontroller"))
        let narrowed = ChangedFileTree.build(from: kept)

        #expect(narrowed.count == 1)
        #expect(narrowed[0].name == "app / Http / Controllers")
        #expect(narrowed[0].children.map(\.path) == ["app/Http/Controllers/UserController.php"])
    }

    @Test("Everything the filter keeps is drawn, because this tree has nothing shut")
    func nothingHasToBeOpened() throws {
        let kept = try #require(ChangedFileFilter.apply(to: files, needle: "user"))
        let rows = ChangedFileTree.rows(from: ChangedFileTree.build(from: kept), collapsed: [])

        #expect(rows.filter { $0.node.file != nil }.map(\.node.path) == paths(kept).sorted())
    }
}
