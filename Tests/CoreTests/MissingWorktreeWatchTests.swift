import Foundation
import Testing
@testable import Core

@Suite("Missing worktree watch")
struct MissingWorktreeWatchTests {
    private func workspace(_ id: String, archived: Bool = false) -> Workspace {
        var row = Workspace(
            id: WorkspaceID(id), repoID: RepoID("project"), name: id, branch: "b/\(id)",
            path: "/tmp/\(id)", baseBranch: "main"
        )
        if archived { row.archive() }
        return row
    }

    private func read(
        _ watch: inout MissingWorktreeWatch,
        _ workspaces: [Workspace],
        exempt: Set<WorkspaceID> = [],
        present: Set<String> = []
    ) -> [String] {
        watch.newlyMissing(among: workspaces, exempt: exempt) { present.contains($0) }.map(\.name)
    }

    private func watching(_ rows: [Workspace]) -> MissingWorktreeWatch {
        var watch = MissingWorktreeWatch()
        _ = read(&watch, rows, present: Set(rows.map(\.path)))
        return watch
    }

    private let exemptA: Set<WorkspaceID> = [WorkspaceID("a")]

    @Test("one absent reading is not reported, the second is")
    func needsTwoReadings() {
        let rows = [workspace("a")]
        var watch = watching(rows)

        let first = read(&watch, rows)
        let second = read(&watch, rows)

        #expect(first.isEmpty)
        #expect(second == ["a"])
    }

    @Test("a folder never seen on disk in this run is not reported")
    func neverSeenIsSilent() {
        var watch = MissingWorktreeWatch()
        let rows = [workspace("a")]

        let first = read(&watch, rows)
        let second = read(&watch, rows)
        let third = read(&watch, rows)

        #expect(first.isEmpty)
        #expect(second.isEmpty)
        #expect(third.isEmpty)
    }

    @Test("every missing folder is reported, whatever sits before it in the list")
    func reportsSeveral() {
        let rows = [workspace("here"), workspace("a"), workspace("b")]
        var watch = watching(rows)

        _ = read(&watch, rows, present: ["/tmp/here"])
        let second = read(&watch, rows, present: ["/tmp/here"])

        #expect(second == ["a", "b"])
    }

    @Test("a folder that comes back between two readings is not reported")
    func cameBackBetweenReadings() {
        let rows = [workspace("a")]
        var watch = watching(rows)

        _ = read(&watch, rows)
        _ = read(&watch, rows, present: ["/tmp/a"])
        let afterReturn = read(&watch, rows)

        #expect(afterReturn.isEmpty)
    }

    @Test("a missing folder is reported once")
    func reportsOnce() {
        let rows = [workspace("a")]
        var watch = watching(rows)

        _ = read(&watch, rows)
        _ = read(&watch, rows)
        let third = read(&watch, rows)
        let fourth = read(&watch, rows)

        #expect(third.isEmpty)
        #expect(fourth.isEmpty)
    }

    @Test("a folder that returns and goes again is reported again")
    func reportsAgainAfterReturning() {
        let rows = [workspace("a")]
        var watch = watching(rows)

        _ = read(&watch, rows)
        _ = read(&watch, rows)
        _ = read(&watch, rows, present: ["/tmp/a"])
        _ = read(&watch, rows)
        let again = read(&watch, rows)

        #expect(again == ["a"])
    }

    @Test("an archived workspace is not watched")
    func archivedIsIgnored() {
        var watch = watching([workspace("a")])
        let rows = [workspace("a", archived: true)]

        _ = read(&watch, rows)
        let second = read(&watch, rows)

        #expect(second.isEmpty)
    }

    @Test("readings taken while exempt do not count")
    func exemptDoesNotCount() {
        let rows = [workspace("a")]
        var watch = watching(rows)

        let firstExempt = read(&watch, rows, exempt: exemptA)
        let secondExempt = read(&watch, rows, exempt: exemptA)
        let first = read(&watch, rows)

        #expect(firstExempt.isEmpty)
        #expect(secondExempt.isEmpty)
        #expect(first.isEmpty)
    }

    @Test("an absent reading is forgotten when the workspace becomes exempt")
    func exemptForgetsAbsence() {
        let rows = [workspace("a")]
        var watch = watching(rows)

        _ = read(&watch, rows)
        _ = read(&watch, rows, exempt: exemptA)
        let afterExempt = read(&watch, rows)

        #expect(afterExempt.isEmpty)
    }

    @Test("being exempt does not forget that the folder was seen")
    func exemptKeepsSeen() {
        let rows = [workspace("a")]
        var watch = watching(rows)

        _ = read(&watch, rows, exempt: exemptA)
        _ = read(&watch, rows)
        let second = read(&watch, rows)

        #expect(second == ["a"])
    }

    @Test("a workspace that leaves the list and returns must be seen again")
    func leavingForgets() {
        let rows = [workspace("a")]
        var watch = watching(rows)

        _ = read(&watch, [])
        _ = read(&watch, rows)
        let second = read(&watch, rows)

        #expect(second.isEmpty)
    }

    @Test("the notice waits for a free slot and is then given once")
    func waitsForSlot() throws {
        let rows = [workspace("a")]
        var watch = watching(rows)
        _ = read(&watch, rows)
        _ = read(&watch, rows)

        let whileBusy = watch.noticeToShow(slotIsFree: false)
        let free = watch.noticeToShow(slotIsFree: true)
        let afterwards = watch.noticeToShow(slotIsFree: true)

        #expect(whileBusy == nil)
        #expect(free?.message.contains("`a`") == true)
        #expect(afterwards == nil)
    }

    @Test("folders lost while the slot is busy arrive in one notice")
    func gathersWhileBusy() throws {
        let rows = [workspace("a"), workspace("b")]
        var watch = watching(rows)
        _ = read(&watch, rows, present: ["/tmp/b"])
        _ = read(&watch, rows, present: ["/tmp/b"])
        _ = read(&watch, rows)
        _ = read(&watch, rows)

        let shown = watch.noticeToShow(slotIsFree: true)
        let notice = try #require(shown)

        #expect(notice.message.contains("2 workspaces"))
        #expect(notice.message.contains("`a`, `b`"))
    }

    @Test("a folder that returns before its notice is shown is not announced")
    func returnedIsNotAnnounced() {
        let rows = [workspace("a")]
        var watch = watching(rows)
        _ = read(&watch, rows)
        _ = read(&watch, rows)
        _ = read(&watch, rows, present: ["/tmp/a"])

        #expect(watch.noticeToShow(slotIsFree: true) == nil)
    }

    @Test("a workspace that leaves before its notice is shown is not announced")
    func leftIsNotAnnounced() {
        let rows = [workspace("a")]
        var watch = watching(rows)
        _ = read(&watch, rows)
        _ = read(&watch, rows)
        _ = read(&watch, [])

        #expect(watch.noticeToShow(slotIsFree: true) == nil)
    }

    @Test("a workspace that becomes exempt before its notice is shown is not announced")
    func exemptIsNotAnnounced() {
        let rows = [workspace("a")]
        var watch = watching(rows)
        _ = read(&watch, rows)
        _ = read(&watch, rows)
        _ = read(&watch, rows, exempt: exemptA)

        #expect(watch.noticeToShow(slotIsFree: true) == nil)
    }

    @Test("the notice says what to do and stays until dismissed")
    func noticeForOne() throws {
        let notice = try #require(MissingWorktreeWatch.notice(for: [workspace("gulf")]))

        #expect(notice.message.contains("`gulf`"))
        #expect(notice.message.contains("archive the workspace"))
        #expect(notice.tone == .warning)
        #expect(notice.dismissal == .untilDismissed)
    }

    @Test("nothing missing means no notice")
    func noNotice() {
        #expect(MissingWorktreeWatch.notice(for: []) == nil)
    }
}
