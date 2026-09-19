import Testing
import Foundation
@testable import Core

@Suite("Store oceans", .tags(.persistence), .scratchDirectory)
struct StoreOceanTests {
    private let seas = OceanCatalog.all.count

    @Test("seeds a fresh store with the whole catalogue, none of it used")
    func seedsFreshStore() async throws {
        let store = try makeTestStore("oceans")
        let oceans = try await store.oceans()
        #expect(oceans.count == seas)
        #expect(oceans.allSatisfy { $0.usedAt == nil })
        #expect(oceans.map(\.name) == oceans.map(\.name).sorted())
        #expect(try await store.unusedOceanCount() == seas)
    }

    @Test("the first claim on a fresh store is a discovery and spends the sea")
    func firstClaimSpendsTheSea() async throws {
        let store = try makeTestStore("oceans")
        let now = Date(timeIntervalSince1970: 1_000_000)
        let pick = try #require(try await store.claimOcean(now: now))
        #expect(pick.isFirstUse)
        #expect(pick.ocean.usedAt == now)
        #expect(pick.remainingUndiscovered == seas - 1)
        #expect(try await store.unusedOceanCount() == seas - 1)
    }

    @Test("never hands the same sea out as a first use twice")
    func neverDiscoversTwice() async throws {
        let store = try makeTestStore("oceans")
        var discovered: Set<String> = []
        for _ in 0..<300 {
            let pick = try #require(try await store.claimOcean())
            if pick.isFirstUse {
                #expect(discovered.insert(pick.ocean.slug).inserted, "\(pick.ocean.slug) was discovered twice")
            }
        }
        #expect(try await store.unusedOceanCount() == seas - discovered.count)
    }

    @Test("draws spent seas too, so a repeat comes up long before the map is full")
    func repeatsBeforeTheMapIsFull() async throws {
        let path = TestScratch.unique("oceans-half") + ".sqlite"
        let store = try Store(path: path)
        let raw = try SQLiteDatabase(path: path)
        try raw.run("UPDATE oceans SET used_at = 42 WHERE rowid % 2 = 0")

        var repeated: OceanPick?
        for _ in 0..<60 {
            let pick = try #require(try await store.claimOcean())
            if !pick.isFirstUse {
                repeated = pick
                break
            }
        }

        let pick = try #require(repeated)
        #expect(pick.notice == nil)
        #expect(pick.remainingUndiscovered == (try await store.unusedOceanCount()))
    }

    @Test("a repeat keeps the first-use date and says nothing")
    func repeatKeepsDiscoveryDate() async throws {
        let path = TestScratch.unique("oceans-full") + ".sqlite"
        let store = try Store(path: path)
        let raw = try SQLiteDatabase(path: path)
        try raw.run("UPDATE oceans SET used_at = 1000000")

        let later = Date(timeIntervalSince1970: 2_000_000)
        for _ in 0..<5 {
            let repeated = try #require(try await store.claimOcean(now: later))
            #expect(repeated.isFirstUse == false)
            #expect(repeated.remainingUndiscovered == 0)
            #expect(repeated.notice == nil)
            #expect(repeated.ocean.usedAt == Date(timeIntervalSince1970: 1_000_000))
        }
        #expect(try await store.unusedOceanCount() == 0)
    }

    @Test("never draws a claimed row the catalogue no longer knows")
    func neverDrawsStrangers() async throws {
        let path = TestScratch.unique("oceans-stranger") + ".sqlite"
        let store = try Store(path: path)
        let raw = try SQLiteDatabase(path: path)
        try raw.run(
            "INSERT INTO oceans (slug, name, latitude, longitude, used_at) VALUES (?, ?, ?, ?, ?)",
            [.text("borneo"), .text("Borneo"), .double(0.96), .double(114.55), .double(42)]
        )

        for _ in 0..<300 {
            let pick = try #require(try await store.claimOcean())
            #expect(pick.ocean.slug != "borneo")
        }
    }

    @Test("a reopen keeps used_at rather than reseeding it away")
    func reopenKeepsUsedFlags() async throws {
        let path = TestScratch.unique("oceans-persist") + ".sqlite"
        let now = Date(timeIntervalSince1970: 42)
        let first = try Store(path: path)
        let pick = try #require(try await first.claimOcean(now: now))

        let second = try Store(path: path)
        #expect(try await second.unusedOceanCount() == seas - 1)
        let stored = try #require(try await second.oceans().first { $0.slug == pick.ocean.slug })
        #expect(stored.usedAt == now)
    }

    @Test("a reopen adds seas the catalogue gained since the table was seeded")
    func reopenSeedsNewSeas() async throws {
        let path = TestScratch.unique("oceans-grown") + ".sqlite"
        _ = try Store(path: path)
        let raw = try SQLiteDatabase(path: path)
        try raw.run("DELETE FROM oceans WHERE slug = 'adriatic-sea'")

        let reopened = try Store(path: path)
        #expect(try await reopened.oceans().count == seas)
        #expect(try await reopened.oceans().contains { $0.slug == "adriatic-sea" })
    }

    @Test("an empty table declines the claim, which is the plant fallback's cue")
    func emptyTableDeclines() async throws {
        let path = TestScratch.unique("oceans-empty") + ".sqlite"
        let store = try Store(path: path)
        let raw = try SQLiteDatabase(path: path)
        try raw.run("DELETE FROM oceans")

        #expect(try await store.claimOcean() == nil)
        #expect(try await store.unusedOceanCount() == 0)
        #expect(try await store.oceans().isEmpty)
    }

    @Test("the seeding migration survives being replayed, and keeps what was claimed")
    func seedingMigrationReplays() async throws {
        let path = TestScratch.unique("oceans-replay") + ".sqlite"
        let now = Date(timeIntervalSince1970: 42)
        let store = try Store(path: path)
        let pick = try #require(try await store.claimOcean(now: now))

        let raw = try SQLiteDatabase(path: path)
        try raw.setUserVersion(0)

        let reopened = try Store(path: path)
        #expect(try await reopened.oceans().count == seas)
        #expect(try await reopened.unusedOceanCount() == seas - 1)
        let stored = try #require(try await reopened.oceans().first { $0.slug == pick.ocean.slug })
        #expect(stored.usedAt == now)
    }

    @Test("migration prunes an unclaimed stranger and keeps a claimed one for the map")
    func pruneKeepsClaimedStrangers() async throws {
        let path = TestScratch.unique("oceans-prune") + ".sqlite"
        _ = try Store(path: path)

        let raw = try SQLiteDatabase(path: path)
        try raw.run(
            "INSERT INTO oceans (slug, name, latitude, longitude) VALUES (?, ?, ?, ?)",
            [.text("greenland"), .text("Greenland"), .double(72), .double(-40)]
        )
        try raw.run(
            "INSERT INTO oceans (slug, name, latitude, longitude, used_at) VALUES (?, ?, ?, ?, ?)",
            [.text("borneo"), .text("Borneo"), .double(0.96), .double(114.55), .double(42)]
        )
        try raw.setUserVersion(0)

        let reopened = try Store(path: path)
        let oceans = try await reopened.oceans()
        #expect(!oceans.contains { $0.slug == "greenland" })
        let kept = try #require(oceans.first { $0.slug == "borneo" })
        #expect(kept.usedAt == Date(timeIntervalSince1970: 42))
        #expect(oceans.count == seas + 1)
        #expect(try await reopened.unusedOceanCount() == seas)
    }
}
