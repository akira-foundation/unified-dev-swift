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
        shownBytes: Int = 0
    ) -> HomeListing {
        var counts = HomeScopeCounts()
        counts.live = live
        counts.archived = archived
        counts.needsYou = needsYou
        counts.running = running
        counts.workspaces = workspaces
        counts.transcripts = transcripts
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

    @Test("a narrowed list says what it was narrowed from")
    func aNarrowedListSaysSo() {
        let text = HomeList.summary(
            listing: listing(shown: 11, considered: 312, live: 11),
            filter: HomeFilter(projects: [RepoID("a")]),
            projects: 4
        )
        #expect(text == "Showing 11 of 312 workspaces")
    }

    @Test("the project clause appears only when there is more than one project")
    func projectsAreNamedWhenThereAreSeveral() {
        #expect(
            HomeList.summary(
                listing: listing(shown: 8, considered: 8, live: 8),
                filter: HomeFilter(scope: .live),
                projects: 1
            ) == "8 live"
        )
        #expect(
            HomeList.summary(
                listing: listing(shown: 8, considered: 8, live: 8),
                filter: HomeFilter(scope: .live),
                projects: 3
            ) == "8 live in 3 projects"
        )
    }

    @Test("narrowed to Live, the line counts live work and names the archive")
    func theLiveLineIsAboutLiveWork() {
        #expect(
            HomeList.summary(
                listing: listing(shown: 3, considered: 20, live: 3, archived: 17),
                filter: HomeFilter(scope: .live),
                projects: 4
            ) == "3 live in 4 projects \u{00B7} 17 archived"
        )
    }

    @Test("finished work is split out of the total under All")
    func archivedIsSplitOut() {
        #expect(
            HomeList.summary(
                listing: listing(shown: 48, considered: 48, live: 18, archived: 30),
                filter: HomeFilter(scope: .all),
                projects: 1
            ) == "48 workspaces \u{00B7} 18 live, 30 archived"
        )
        #expect(
            HomeList.summary(
                listing: listing(shown: 47, considered: 47, live: 35, archived: 12),
                filter: HomeFilter(scope: .all),
                projects: 6
            ) == "47 workspaces in 6 projects \u{00B7} 35 live, 12 archived"
        )
    }

    @Test("a machine with nothing archived does not mention it")
    func nothingArchivedIsNotMentioned() {
        #expect(
            HomeList.summary(
                listing: listing(shown: 5, considered: 5, live: 5),
                filter: HomeFilter(scope: .all),
                projects: 1
            ) == "5 workspaces"
        )
        #expect(
            HomeList.summary(
                listing: listing(shown: 5, considered: 5, live: 5),
                filter: HomeFilter(scope: .live),
                projects: 1
            ) == "5 live"
        )
    }

    @Test("the line follows the chip")
    func theLineFollowsTheChip() {
        let machine = listing(
            shown: 17, considered: 20, live: 3, archived: 17, needsYou: 2, running: 1
        )
        #expect(
            HomeList.summary(listing: machine, filter: HomeFilter(scope: .archived), projects: 4)
                == "17 archived in 4 projects"
        )
        #expect(
            HomeList.summary(listing: machine, filter: HomeFilter(scope: .needsYou), projects: 4)
                == "2 waiting on you"
        )
        #expect(
            HomeList.summary(listing: machine, filter: HomeFilter(scope: .running), projects: 4)
                == "1 running"
        )
    }

    @Test("an empty scope says so in words rather than with a nought")
    func anEmptyScopeSaysSoInWords() {
        let quiet = listing(shown: 0, considered: 20, live: 3, archived: 17)
        #expect(
            HomeList.summary(listing: quiet, filter: HomeFilter(scope: .needsYou), projects: 4)
                == "Nothing waiting on you"
        )
        #expect(
            HomeList.summary(listing: quiet, filter: HomeFilter(scope: .running), projects: 4)
                == "Nothing running"
        )
        let allArchived = listing(shown: 0, considered: 17, live: 0, archived: 17)
        #expect(
            HomeList.summary(listing: allArchived, filter: HomeFilter(scope: .live), projects: 4)
                == "Nothing live \u{00B7} 17 archived"
        )
    }

    @Test("the archived line carries what the archive holds and how big the file is")
    func theArchivedLineCarriesBothTotals() {
        let machine = listing(
            shown: 17, considered: 20, live: 3, archived: 17, shownBytes: 7_600_000
        )
        let tidy = DatabaseSize(pageSize: 4_096, pageCount: 10_000, freePageCount: 10)

        #expect(
            HomeList.summary(
                listing: machine, filter: HomeFilter(scope: .archived), projects: 4,
                database: tidy
            ) == "17 archived in 4 projects, holding \(ArchiveDeletion.bytes(7_600_000)) "
                + "\u{00B7} Unified Dev\u{2019}s database is \(ArchiveDeletion.bytes(40_960_000))"
        )
    }

    @Test("the free space is named only when there is a compaction to explain")
    func namesFreeSpaceOnlyWhenItIsWorthReclaiming() {
        let machine = listing(shown: 17, considered: 20, archived: 17, shownBytes: 7_600_000)
        let loose = DatabaseSize(pageSize: 4_096, pageCount: 10_000, freePageCount: 4_000)

        let text = HomeList.summary(
            listing: machine, filter: HomeFilter(scope: .archived), projects: 1, database: loose
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
                    listing: machine, filter: HomeFilter(scope: scope), projects: 4, database: size
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
                listing: quiet, filter: HomeFilter(scope: .archived), projects: 4, database: size
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
                projects: 4,
                database: size
            ) == "Showing 11 of 312 workspaces, holding \(ArchiveDeletion.bytes(2_100_000)) "
                + "\u{00B7} Unified Dev\u{2019}s database is \(ArchiveDeletion.bytes(40_960_000))"
        )
        #expect(
            HomeList.summary(
                listing: machine,
                filter: HomeFilter(projects: [RepoID("a")], scope: .all),
                projects: 4,
                database: size
            ) == "Showing 11 of 312 workspaces"
        )
    }

    @Test("an unmeasured archive says nothing about bytes at all")
    func saysNothingBeforeAnythingIsMeasured() {
        let machine = listing(shown: 17, considered: 20, live: 3, archived: 17)
        #expect(
            HomeList.summary(listing: machine, filter: HomeFilter(scope: .archived), projects: 4)
                == "17 archived in 4 projects"
        )
    }

    @Test("a search counts its results and quotes what was typed")
    func aSearchCountsResults() {
        let found = listing(
            shown: 4, considered: 47, workspaces: 4, transcripts: 37, isSearching: true
        )
        #expect(
            HomeList.summary(listing: found, filter: HomeFilter(query: "sidebar", scope: .all), projects: 6)
                == "41 results for \u{201C}sidebar\u{201D}"
        )
        #expect(
            HomeList.summary(
                listing: found,
                filter: HomeFilter(query: "sidebar", scope: .workspaces),
                projects: 6
            ) == "4 results for \u{201C}sidebar\u{201D}"
        )
    }

    @Test("the search sentence quotes the user properly")
    func theQuotesAreTypographic() {
        let text = HomeList.summary(
            listing: listing(shown: 1, considered: 4, workspaces: 1, isSearching: true),
            filter: HomeFilter(query: "  blue  ", scope: .all),
            projects: 1
        )
        #expect(text.contains("\u{201C}blue\u{201D}"))
        #expect(!text.contains("\""))
    }

    @Test("nothing at all says nothing at all")
    func nothingSaysNothing() {
        #expect(HomeList.summary(listing: .empty, filter: HomeFilter(), projects: 0).isEmpty)
    }
}
