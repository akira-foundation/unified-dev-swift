import Foundation
import Testing
@testable import Core

@Suite("Deleting archived workspaces past their limits", .tags(.persistence), .scratchDirectory)
struct ArchiveRetentionTests {
    private let now = Date(timeIntervalSince1970: 2_000_000_000)

    private func footprint(_ name: String, daysAgo: Double, megabytes: Int = 1) -> ArchivedWorkspaceFootprint {
        ArchivedWorkspaceFootprint(
            workspace: Workspace(
                id: WorkspaceID(name),
                repoID: RepoID("repo"),
                name: name,
                branch: name,
                path: "/tmp/\(name)",
                baseBranch: "main",
                state: .archived,
                archivedAt: now.addingTimeInterval(-daysAgo * 86_400)
            ),
            repoName: "repo",
            sessionCount: 0,
            messageCount: 0,
            transcriptBytes: megabytes * 1_000_000,
            otherBytes: 0,
            reviewCommentCount: 0,
            hasNote: false
        )
    }

    private func names(_ footprints: [ArchivedWorkspaceFootprint]) -> [String] {
        footprints.map(\.workspace.name)
    }

    @Test("with no limit set nothing is ever deleted")
    func offDeletesNothing() {
        let retention = ArchiveRetention()
        #expect(!retention.isEnabled)
        #expect(retention.expired(in: [footprint("ancient", daysAgo: 9_000)], now: now).isEmpty)
    }

    @Test("either limit alone turns retention on")
    func eitherLimitEnables() {
        #expect(ArchiveRetention(days: 30).isEnabled)
        #expect(ArchiveRetention(megabytes: 500).isEnabled)
    }

    @Test("a limit of zero or less is no limit rather than a limit nothing can meet")
    func nonPositiveLimitsAreOff() {
        let retention = ArchiveRetention(days: 0, megabytes: -1)
        #expect(!retention.isEnabled)
        #expect(retention.expired(in: [footprint("ancient", daysAgo: 9_000)], now: now).isEmpty)
    }

    @Test("age deletes what reached the limit and keeps what is one second short of it")
    func ageBoundary() {
        let retention = ArchiveRetention(days: 30)
        let reached = footprint("reached", daysAgo: 30)
        let short = footprint("short", daysAgo: 30 - 1.0 / 86_400)
        #expect(names(retention.expired(in: [short, reached], now: now)) == ["reached"])
    }

    @Test("the size limit deletes oldest first and stops as soon as the total fits")
    func sizeDeletesOldestFirst() {
        let retention = ArchiveRetention(megabytes: 25)
        let expired = retention.expired(
            in: [
                footprint("newest", daysAgo: 2, megabytes: 10),
                footprint("oldest", daysAgo: 10, megabytes: 10),
                footprint("middle", daysAgo: 5, megabytes: 10),
            ],
            now: now
        )
        #expect(names(expired) == ["oldest"])
    }

    @Test("a total exactly at the size limit is within it")
    func sizeBoundary() {
        let retention = ArchiveRetention(megabytes: 20)
        let fits = [footprint("a", daysAgo: 5, megabytes: 10), footprint("b", daysAgo: 4, megabytes: 10)]
        #expect(retention.expired(in: fits, now: now).isEmpty)
    }

    @Test("one byte over the limit is over it, so a megabyte is a million bytes")
    func sizeIsCountedInMillions() {
        let retention = ArchiveRetention(megabytes: 1)
        let over = ArchivedWorkspaceFootprint(
            workspace: footprint("over", daysAgo: 5).workspace,
            repoName: "repo", sessionCount: 0, messageCount: 0,
            transcriptBytes: 1_000_000, otherBytes: 1, reviewCommentCount: 0, hasNote: false
        )
        #expect(names(retention.expired(in: [over], now: now)) == ["over"])
    }

    @Test("the size limit may take something exactly a day old and not one second younger")
    func graceBoundary() {
        let retention = ArchiveRetention(megabytes: 1)
        let aDay = footprint("a-day", daysAgo: 1, megabytes: 5)
        let younger = footprint("younger", daysAgo: 1 - 1.0 / 86_400, megabytes: 5)
        #expect(names(retention.expired(in: [aDay], now: now)) == ["a-day"])
        #expect(retention.expired(in: [younger], now: now).isEmpty)
    }

    @Test("older records go when that brings the total within the limit, leaving the recent one")
    func sizeLimitSparesTheRecentlyArchived() {
        let retention = ArchiveRetention(megabytes: 2)
        let expired = retention.expired(
            in: [footprint("old", daysAgo: 2, megabytes: 5), footprint("just-archived", daysAgo: 0.5, megabytes: 1)],
            now: now
        )
        #expect(names(expired) == ["old"])
    }

    @Test("when only recent records keep the total over the limit, nothing older is deleted for it")
    func anUnreachableLimitDeletesNothing() {
        let retention = ArchiveRetention(megabytes: 1_000)
        let expired = retention.expired(
            in: [footprint("old", daysAgo: 5, megabytes: 900), footprint("just-archived", daysAgo: 0.1, megabytes: 2_000)],
            now: now
        )
        #expect(expired.isEmpty)
    }

    @Test("what age already deletes counts towards the size limit, so nothing extra goes")
    func limitsCombine() {
        let retention = ArchiveRetention(days: 30, megabytes: 14)
        let expired = retention.expired(
            in: [
                footprint("ancient", daysAgo: 40, megabytes: 10),
                footprint("old", daysAgo: 10, megabytes: 10),
                footprint("recent", daysAgo: 5, megabytes: 5),
            ],
            now: now
        )
        #expect(names(expired) == ["ancient", "old"])

        let fits = ArchiveRetention(days: 30, megabytes: 20).expired(
            in: [
                footprint("ancient", daysAgo: 40, megabytes: 10),
                footprint("old", daysAgo: 10, megabytes: 10),
                footprint("recent", daysAgo: 5, megabytes: 5),
            ],
            now: now
        )
        #expect(names(fits) == ["ancient"])
    }

    @Test("a protected record past its age is spared now and not counted, since it goes at the next check")
    func protectedByAge() {
        let retention = ArchiveRetention(days: 30, megabytes: 15)
        let expired = retention.expired(
            in: [
                footprint("open", daysAgo: 40, megabytes: 10),
                footprint("old", daysAgo: 10, megabytes: 10),
                footprint("recent", daysAgo: 5, megabytes: 5),
            ],
            now: now,
            protecting: [WorkspaceID("open")]
        )
        #expect(expired.isEmpty)
    }

    @Test("a protected oldest record stops the size limit rather than sending newer ones in its place")
    func protectedOldestStopsTheSizeLimit() {
        let retention = ArchiveRetention(megabytes: 1_000)
        let rows = [
            footprint("open", daysAgo: 5, megabytes: 1_200),
            footprint("newer", daysAgo: 3, megabytes: 100),
            footprint("newest", daysAgo: 2, megabytes: 100),
        ]
        #expect(retention.expired(in: rows, now: now, protecting: [WorkspaceID("open")]).isEmpty)
        #expect(names(retention.expired(in: rows, now: now)) == ["open"])
    }

    @Test("a protected record that is not the oldest still lets older ones go")
    func protectedNewerKeepsOlderDeletable() {
        let retention = ArchiveRetention(megabytes: 15)
        let expired = retention.expired(
            in: [
                footprint("oldest", daysAgo: 9, megabytes: 10),
                footprint("open", daysAgo: 5, megabytes: 10),
            ],
            now: now,
            protecting: [WorkspaceID("open")]
        )
        #expect(names(expired) == ["oldest"])
    }

    @Test("an absurd size limit cannot overflow into deleting everything")
    func hugeLimitDoesNotOverflow() {
        let retention = ArchiveRetention(megabytes: Int.max)
        #expect(retention.expired(in: [footprint("old", daysAgo: 9, megabytes: 500)], now: now).isEmpty)
    }

    @Test("the limits survive a round trip, and turning one off removes it")
    func persists() async throws {
        let store = try makeTestStore("archive-retention")
        #expect(await ArchiveRetention.load(from: store) == ArchiveRetention())

        try await ArchiveRetention(days: 30, megabytes: 5_000).save(to: store)
        #expect(await ArchiveRetention.load(from: store) == ArchiveRetention(days: 30, megabytes: 5_000))

        try await ArchiveRetention(days: nil, megabytes: 5_000).save(to: store)
        #expect(await ArchiveRetention.load(from: store) == ArchiveRetention(megabytes: 5_000))
        #expect(try await store.setting(ArchiveRetention.daysKey) == nil)
    }

    @Test("a stored value that is not a positive number reads as no limit")
    func garbageReadsAsOff() async throws {
        let store = try makeTestStore("archive-retention-garbage")
        try await store.setSetting(ArchiveRetention.daysKey, "soon")
        try await store.setSetting(ArchiveRetention.megabytesKey, "-5")
        #expect(await ArchiveRetention.load(from: store) == ArchiveRetention())
    }

    @Test("the footer names everything the next check would delete, and only then")
    func footerForecast() {
        let quiet = ArchiveRetention.footer(wouldDelete: [])
        let forecast = ArchiveRetention.footer(wouldDelete: [
            footprint("old", daysAgo: 40, megabytes: 3), footprint("older", daysAgo: 50, megabytes: 4),
        ])
        #expect(!quiet.contains("At the next check"))
        #expect(forecast.contains("2 archived workspaces, \(ArchiveDeletion.bytes(7_000_000))"))
    }

    @Test("the notice stays until read and counts what went, and nothing deleted says nothing")
    func noticeCountsWhatWent() throws {
        #expect(ArchiveRetention.notice(deleted: []) == nil)

        let notice = try #require(ArchiveRetention.notice(deleted: [
            footprint("old", daysAgo: 40, megabytes: 3), footprint("older", daysAgo: 50, megabytes: 4),
        ]))
        #expect(notice.message.contains("2 archived workspaces, \(ArchiveDeletion.bytes(7_000_000))"))
        #expect(notice.dismissal == .untilDismissed)
    }
}
