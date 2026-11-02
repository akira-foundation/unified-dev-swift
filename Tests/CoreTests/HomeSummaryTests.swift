import Testing
@testable import Core

@Suite("What Home says about its list")
struct HomeSummaryTests {
    private func listing(
        shown: Int,
        considered: Int,
        live: Int = 0,
        archived: Int = 0,
        needsYou: Int = 0,
        running: Int = 0,
        workspaces: Int = 0,
        transcripts: Int = 0,
        isSearching: Bool = false,
        shownBytes: Int = 0,
        projects: Int = 4,
        liveProjects: Int = 4,
        archivedProjects: Int = 4
    ) -> HomeListing {
        var counts = HomeScopeCounts()
        counts.live = live
        counts.archived = archived
        counts.needsYou = needsYou
        counts.running = running
        counts.workspaces = workspaces
        counts.transcripts = transcripts
        counts.projects = projects
        counts.liveProjects = liveProjects
        counts.archivedProjects = archivedProjects
        return HomeListing(
            groups: [],
            counts: counts,
            isSearching: isSearching,
            shown: shown,
            considered: considered,
            archived: archived,
            shownArchived: archived,
            shownBytes: shownBytes
        )
    }

    private func repo(_ id: String) -> Repo {
        Repo(id: RepoID(id), name: id, path: "/tmp/\(id)")
    }

    private func workspace(
        _ name: String, in repo: String, state: WorkspaceState = .active
    ) -> Workspace {
        Workspace(
            id: WorkspaceID(name),
            repoID: RepoID(repo),
            name: name,
            branch: name,
            path: "/tmp/\(name)",
            baseBranch: "main",
            state: state
        )
    }

    @Test("the archived line names the projects its workspaces are in, not every project")
    func theArchivedLineCountsItsOwnProjects() {
        let archived = ["one", "two", "three"].map { workspace($0, in: "a", state: .archived) }
            + ["four", "five"].map { workspace($0, in: "b", state: .archived) }
        let filter = HomeFilter(scope: .archived)

        let built = HomeList.build(
            repos: [repo("a"), repo("b"), repo("c")],
            workspaces: [],
            archived: archived,
            filter: filter
        )

        #expect(HomeList.summary(listing: built, filter: filter) == "5 archived in 2 projects")
    }

    @Test("each line counts the projects of the workspaces it counts")
    func eachLineCountsItsOwnProjects() {
        let built = { (scope: HomeScope) -> String in
            let filter = HomeFilter(scope: scope)
            return HomeList.summary(
                listing: HomeList.build(
                    repos: [repo("a"), repo("b"), repo("c"), repo("d")],
                    workspaces: [
                        workspace("one", in: "a"),
                        workspace("two", in: "a"),
                        workspace("three", in: "b"),
                    ],
                    archived: [workspace("four", in: "c", state: .archived)],
                    filter: filter
                ),
                filter: filter
            )
        }

        #expect(built(.live) == "3 live in 2 projects \u{00B7} 1 archived")
        #expect(built(.archived) == "1 archived")
        #expect(built(.all) == "4 workspaces in 3 projects \u{00B7} 3 live, 1 archived")
    }

    @Test("a project with both live and archived work counts once under All")
    func aProjectWithBothKindsCountsOnce() {
        let filter = HomeFilter(scope: .all)
        let built = HomeList.build(
            repos: [repo("a"), repo("b")],
            workspaces: [workspace("one", in: "a"), workspace("two", in: "b")],
            archived: [workspace("three", in: "b", state: .archived)],
            filter: filter
        )

        #expect(
            HomeList.summary(listing: built, filter: filter)
                == "3 workspaces in 2 projects \u{00B7} 2 live, 1 archived"
        )
    }

    @Test("a narrowed list says what it was narrowed from")
    func aNarrowedListSaysSo() {
        let text = HomeList.summary(
            listing: listing(shown: 11, considered: 312, live: 11),
            filter: HomeFilter(projects: [RepoID("a")])
        )
        #expect(text == "Showing 11 of 312 workspaces")
    }

    @Test("the project clause appears only when there is more than one project")
    func projectsAreNamedWhenThereAreSeveral() {
        #expect(
            HomeList.summary(
                listing: listing(shown: 8, considered: 8, live: 8, liveProjects: 1),
                filter: HomeFilter(scope: .live)
            ) == "8 live"
        )
        #expect(
            HomeList.summary(
                listing: listing(shown: 8, considered: 8, live: 8, liveProjects: 3),
                filter: HomeFilter(scope: .live)
            ) == "8 live in 3 projects"
        )
    }

    @Test("narrowed to Live, the line counts live work and names the archive")
    func theLiveLineIsAboutLiveWork() {
        #expect(
            HomeList.summary(
                listing: listing(shown: 3, considered: 20, live: 3, archived: 17, liveProjects: 4),
                filter: HomeFilter(scope: .live)
            ) == "3 live in 4 projects \u{00B7} 17 archived"
        )
    }

    @Test("finished work is split out of the total under All")
    func archivedIsSplitOut() {
        #expect(
            HomeList.summary(
                listing: listing(shown: 48, considered: 48, live: 18, archived: 30, projects: 1),
                filter: HomeFilter(scope: .all)
            ) == "48 workspaces \u{00B7} 18 live, 30 archived"
        )
        #expect(
            HomeList.summary(
                listing: listing(shown: 47, considered: 47, live: 35, archived: 12, projects: 6),
                filter: HomeFilter(scope: .all)
            ) == "47 workspaces in 6 projects \u{00B7} 35 live, 12 archived"
        )
    }

    @Test("a machine with nothing archived does not mention it")
    func nothingArchivedIsNotMentioned() {
        #expect(
            HomeList.summary(
                listing: listing(shown: 5, considered: 5, live: 5, projects: 1),
                filter: HomeFilter(scope: .all)
            ) == "5 workspaces"
        )
        #expect(
            HomeList.summary(
                listing: listing(shown: 5, considered: 5, live: 5, liveProjects: 1),
                filter: HomeFilter(scope: .live)
            ) == "5 live"
        )
    }

    @Test("the line follows the chip")
    func theLineFollowsTheChip() {
        let machine = listing(
            shown: 17, considered: 20, live: 3, archived: 17, needsYou: 2, running: 1,
            archivedProjects: 4
        )
        #expect(
            HomeList.summary(listing: machine, filter: HomeFilter(scope: .archived))
                == "17 archived in 4 projects"
        )
        #expect(
            HomeList.summary(listing: machine, filter: HomeFilter(scope: .needsYou))
                == "2 waiting on you"
        )
        #expect(
            HomeList.summary(listing: machine, filter: HomeFilter(scope: .running))
                == "1 running"
        )
    }

    @Test("an empty scope says so in words rather than with a nought")
    func anEmptyScopeSaysSoInWords() {
        let quiet = listing(shown: 0, considered: 20, live: 3, archived: 17)
        #expect(
            HomeList.summary(listing: quiet, filter: HomeFilter(scope: .needsYou))
                == "Nothing waiting on you"
        )
        #expect(
            HomeList.summary(listing: quiet, filter: HomeFilter(scope: .running))
                == "Nothing running"
        )
        let allArchived = listing(shown: 0, considered: 17, live: 0, archived: 17)
        #expect(
            HomeList.summary(listing: allArchived, filter: HomeFilter(scope: .live))
                == "Nothing live \u{00B7} 17 archived"
        )
    }

    @Test("the archived line carries what the archive holds and how big the file is")
    func theArchivedLineCarriesBothTotals() {
        let machine = listing(
            shown: 17, considered: 20, live: 3, archived: 17, shownBytes: 7_600_000,
            archivedProjects: 4
        )
        let tidy = DatabaseSize(pageSize: 4_096, pageCount: 10_000, freePageCount: 10)

        #expect(
            HomeList.summary(
                listing: machine, filter: HomeFilter(scope: .archived),
                database: tidy
            ) == "17 archived in 4 projects, holding \(ArchiveDeletion.bytes(7_600_000)) "
                + "\u{00B7} Unified Dev\u{2019}s database is \(ArchiveDeletion.bytes(40_960_000))"
        )
    }

    @Test("the free space is named only when there is a compaction to explain")
    func namesFreeSpaceOnlyWhenItIsWorthReclaiming() {
        let machine = listing(
            shown: 17, considered: 20, archived: 17, shownBytes: 7_600_000, archivedProjects: 1
        )
        let loose = DatabaseSize(pageSize: 4_096, pageCount: 10_000, freePageCount: 4_000)

        let text = HomeList.summary(
            listing: machine, filter: HomeFilter(scope: .archived), database: loose
        )
        #expect(loose.isWorthCompacting)
        #expect(text.hasSuffix("\(ArchiveDeletion.bytes(16_384_000)) of it unused"))
        #expect(text.hasPrefix("17 archived, holding"))
    }

    @Test("the database is named under the Archived chip alone")
    func theDatabaseIsNamedOnlyUnderArchived() {
        let machine = listing(
            shown: 20, considered: 20, live: 3, archived: 17, shownBytes: 7_600_000
        )
        let size = DatabaseSize(pageSize: 4_096, pageCount: 10_000, freePageCount: 10)
        for scope in [HomeScope.all, .live, .needsYou, .running] {
            #expect(
                !HomeList.summary(
                    listing: machine, filter: HomeFilter(scope: scope), database: size
                ).contains("database")
            )
        }
    }

    @Test("an empty archive still says how big the file is")
    func anEmptyArchiveStillNamesTheFile() {
        let quiet = listing(shown: 0, considered: 20, live: 20, archived: 0)
        let size = DatabaseSize(pageSize: 4_096, pageCount: 10_000, freePageCount: 10)
        #expect(
            HomeList.summary(
                listing: quiet, filter: HomeFilter(scope: .archived), database: size
            ) == "Nothing archived \u{00B7} Unified Dev\u{2019}s database is "
                + "\(ArchiveDeletion.bytes(40_960_000))"
        )
    }

    @Test("a project filter narrows the line and keeps the storage on it")
    func aProjectFilterKeepsTheStorageClauses() {
        let machine = listing(shown: 11, considered: 312, archived: 11, shownBytes: 2_100_000)
        let size = DatabaseSize(pageSize: 4_096, pageCount: 10_000, freePageCount: 10)

        #expect(
            HomeList.summary(
                listing: machine,
                filter: HomeFilter(projects: [RepoID("a")], scope: .archived),
                database: size
            ) == "Showing 11 of 312 workspaces, holding \(ArchiveDeletion.bytes(2_100_000)) "
                + "\u{00B7} Unified Dev\u{2019}s database is \(ArchiveDeletion.bytes(40_960_000))"
        )
        #expect(
            HomeList.summary(
                listing: machine,
                filter: HomeFilter(projects: [RepoID("a")], scope: .all),
                database: size
            ) == "Showing 11 of 312 workspaces"
        )
    }

    @Test("an unmeasured archive says nothing about bytes at all")
    func saysNothingBeforeAnythingIsMeasured() {
        let machine = listing(shown: 17, considered: 20, live: 3, archived: 17, archivedProjects: 4)
        #expect(
            HomeList.summary(listing: machine, filter: HomeFilter(scope: .archived))
                == "17 archived in 4 projects"
        )
    }

    @Test("a search counts its results and quotes what was typed")
    func aSearchCountsResults() {
        let found = listing(
            shown: 4, considered: 47, workspaces: 4, transcripts: 37, isSearching: true
        )
        #expect(
            HomeList.summary(listing: found, filter: HomeFilter(query: "sidebar", scope: .all))
                == "41 results for \u{201C}sidebar\u{201D}"
        )
        #expect(
            HomeList.summary(
                listing: found,
                filter: HomeFilter(query: "sidebar", scope: .workspaces)
            ) == "4 results for \u{201C}sidebar\u{201D}"
        )
    }

    @Test("the search sentence quotes the user properly")
    func theQuotesAreTypographic() {
        let text = HomeList.summary(
            listing: listing(shown: 1, considered: 4, workspaces: 1, isSearching: true),
            filter: HomeFilter(query: "  blue  ", scope: .all)
        )
        #expect(text.contains("\u{201C}blue\u{201D}"))
        #expect(!text.contains("\""))
    }

    @Test("nothing at all says nothing at all")
    func nothingSaysNothing() {
        #expect(HomeList.summary(listing: .empty, filter: HomeFilter()).isEmpty)
    }
}
