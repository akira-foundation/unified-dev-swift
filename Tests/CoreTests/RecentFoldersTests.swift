import Foundation
import Testing
@testable import Core

@Suite("The folders opened recently")
struct RecentFoldersTests {
    @Test("the folder just opened goes to the front")
    func newestFirst() {
        let kept = RecentFolders.adding("/a/beacon", to: ["/a/harbour"])

        #expect(kept == ["/a/beacon", "/a/harbour"])
    }

    @Test("opening one again moves it up rather than listing it twice")
    func reopeningMovesUp() {
        let kept = RecentFolders.adding("/a/harbour", to: ["/a/beacon", "/a/harbour", "/a/almanac"])

        #expect(kept == ["/a/harbour", "/a/beacon", "/a/almanac"])
    }

    @Test("the same folder written two ways is one entry, so a trailing slash is not a second row")
    func normalisesBeforeComparing() {
        let kept = RecentFolders.adding("/a/harbour/", to: ["/a/harbour"])

        #expect(kept == ["/a/harbour"])
    }

    @Test("the list is capped, and it is the oldest that falls off")
    func capsTheList() {
        let existing = (1...10).map { "/a/project\($0)" }

        let kept = RecentFolders.adding("/a/newest", to: existing)

        #expect(kept.count == 10)
        #expect(kept.first == "/a/newest")
        #expect(!kept.contains("/a/project10"))
    }

    @Test("a limit of zero still keeps the folder just opened, rather than keeping nothing")
    func neverKeepsNothing() {
        #expect(RecentFolders.adding("/a/harbour", to: [], limit: 0) == ["/a/harbour"])
    }

    @Test("an empty path is not recorded")
    func ignoresEmpty() {
        #expect(RecentFolders.adding("", to: ["/a/harbour"]) == ["/a/harbour"])
        #expect(RecentFolders.adding("   ", to: ["/a/harbour"]) == ["/a/harbour"])
    }

    @Test("a folder is forgotten on request")
    func forgets() {
        #expect(RecentFolders.removing("/a/harbour", from: ["/a/beacon", "/a/harbour"]) == ["/a/beacon"])
    }

    @Test("a folder that is no longer on disk is not offered")
    func dropsWhatIsGone() {
        let offered = RecentFolders.onDisk(["/a/harbour", "/a/gone"]) { $0 != "/a/gone" }

        #expect(offered == ["/a/harbour"])
    }

    @Test("two entries that resolve to one folder are offered once")
    func dedupesOnReading() {
        let offered = RecentFolders.onDisk(["/a/harbour", "/a/harbour/"]) { _ in true }

        #expect(offered == ["/a/harbour"])
    }

    @Test("what was remembered is what is read back, newest first")
    func roundTripsThroughTheSettingsTable() async throws {
        let store = try Store(path: TestScratch.unique("unifieddev-recent") + ".sqlite")
        let present = TestScratch.unique("unifieddev-folder")
        let other = TestScratch.unique("unifieddev-folder")
        for path in [present, other] {
            try FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true)
        }

        try await DirectoryPreferences.remember(other, in: store)
        try await DirectoryPreferences.remember(present, in: store)

        #expect(await DirectoryPreferences.recentFolders(from: store) == [present, other])

        try await DirectoryPreferences.forget(other, in: store)

        #expect(await DirectoryPreferences.recentFolders(from: store) == [present])
    }
}
