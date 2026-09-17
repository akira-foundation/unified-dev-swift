import Testing
@testable import Core

@Suite("Menu bar summary")
struct MenuBarSummaryTests {
    @Test("says nothing at all when there is nothing to say")
    func quietWhenIdle() {
        #expect(MenuBarSummary.segments(waiting: 0, unread: 0).isEmpty)
    }

    @Test("shows a count only for the thing that has one")
    func dropsZeroes() {
        let waiting = MenuBarSummary.segments(waiting: 2, unread: 0)
        #expect(waiting.map(\.symbolName) == [MenuBarSummary.waitingSymbol])
        #expect(waiting.first?.count == 2)

        let unread = MenuBarSummary.segments(waiting: 0, unread: 5)
        #expect(unread.map(\.symbolName) == [MenuBarSummary.unreadSymbol])
        #expect(unread.first?.count == 5)
    }

    @Test("puts the thing that costs something before the thing that will keep")
    func ordersWaitingFirst() {
        let segments = MenuBarSummary.segments(waiting: 3, unread: 1)

        #expect(segments.count == 2)
        #expect(segments.map(\.symbolName) == [MenuBarSummary.waitingSymbol, MenuBarSummary.unreadSymbol])
        #expect(segments.map(\.count) == [3, 1])
    }

    @Test("never draws the running dot in the strip")
    func noRunningSegment() {
        let symbols = MenuBarSummary.segments(waiting: 3, unread: 1).map(\.symbolName)

        #expect(!symbols.contains(MenuBarSummary.runningSymbol))
    }

    @Test("spells the glyphs out in words on hover")
    func tooltipExplainsTheGlyphs() {
        #expect(MenuBarSummary.tooltip(waiting: 1, unread: 0) == "1 agent waiting on you")
        #expect(MenuBarSummary.tooltip(waiting: 3, unread: 0) == "3 agents waiting on you")
        #expect(MenuBarSummary.tooltip(waiting: 0, unread: 1) == "1 unread result")
        #expect(MenuBarSummary.tooltip(waiting: 2, unread: 4) == "2 agents waiting on you, 4 unread results")
    }

    @Test("a bare strip hovers as nothing needing a person")
    func tooltipWhenBare() {
        #expect(MenuBarSummary.tooltip(waiting: 0, unread: 0) == MenuBarSummary.idleTooltip)
        #expect(MenuBarSummary.tooltip(waiting: 0, unread: 0) != MenuBarSummary.emptyTitle)
    }

    @Test("a workspace waiting on a person is listed, first")
    func waitingIsListed() {
        let asking = workspace(name: "Test unifieddev mcp")
        let sections = MenuBarSummary.sections(
            in: [asking],
            isRunning: { _ in true },
            isAwaitingPermission: { $0.id == asking.id }
        )

        #expect(sections.first?.heading == MenuBarSummary.waitingHeading)
        #expect(sections.first?.symbolName == MenuBarSummary.waitingSymbol)
        #expect(sections.first?.workspaces.map(\.name) == ["Test unifieddev mcp"])
    }

    @Test("a blocked agent is not also listed as running")
    func waitingOutranksRunning() {
        let asking = workspace(name: "Asking")
        let working = workspace(name: "Working")
        let sections = MenuBarSummary.sections(
            in: [asking, working],
            isRunning: { _ in true },
            isAwaitingPermission: { $0.id == asking.id }
        )

        #expect(sections.map(\.heading) == [MenuBarSummary.waitingHeading, MenuBarSummary.runningHeading])
        #expect(sections.last?.workspaces.map(\.name) == ["Working"])
    }

    @Test("unread lists exactly what the unread count counted")
    func unreadMatchesTheCount() {
        let read = workspace(name: "Read")
        let unread = workspace(name: "Unread", unread: true)
        let busy = workspace(name: "Busy", unread: true)
        let all = [read, unread, busy]
        let sections = MenuBarSummary.sections(
            in: all,
            isRunning: { $0.id == busy.id },
            isAwaitingPermission: { _ in false }
        )

        let listed = sections.first { $0.heading == MenuBarSummary.unreadHeading }
        #expect(listed?.workspaces.map(\.name) == ["Unread"])
        #expect(listed?.workspaces.count == DockBadge.unreadCount(in: all) { $0.id == busy.id })
    }

    @Test("the badge and the menu agree about every workspace, not just one")
    func unreadRuleIsStatedOnce() {
        for isUnread in [false, true] {
            for isRunning in [false, true] {
                let one = workspace(name: "W", unread: isUnread)
                let running: (Workspace) -> Bool = { _ in isRunning }
                let counted = DockBadge.unreadCount(in: [one], isRunning: running)
                let sections = MenuBarSummary.sections(
                    in: [one], isRunning: running, isAwaitingPermission: { _ in false }
                )
                let listed = sections
                    .first { $0.heading == MenuBarSummary.unreadHeading }?
                    .workspaces.count ?? 0

                #expect(counted == listed, "unread \(isUnread), running \(isRunning)")
                #expect(DockBadge.hasUnreadResult(one, isRunning: running) == (counted == 1))
            }
        }
    }

    @Test("no two headings can be told apart by a preposition")
    func headingsShareNoWords() {
        let headings = [
            MenuBarSummary.waitingHeading,
            MenuBarSummary.runningHeading,
            MenuBarSummary.unreadHeading,
        ]
        let words = headings.map { Set($0.lowercased().split(separator: " ")) }

        for (index, one) in words.enumerated() {
            for other in words[(index + 1)...] {
                #expect(one.isDisjoint(with: other))
            }
        }
    }

    @Test("an idle machine has no lists at all")
    func nothingToList() {
        let sections = MenuBarSummary.sections(
            in: [workspace(name: "Quiet")],
            isRunning: { _ in false },
            isAwaitingPermission: { _ in false }
        )

        #expect(sections.isEmpty)
    }

    private func workspace(name: String, unread: Bool = false) -> Workspace {
        Workspace(
            repoID: RepoID("repo"),
            name: name,
            branch: "feature/\(name)",
            path: "/tmp/\(name)",
            baseBranch: "main",
            setupState: .succeeded,
            unread: unread
        )
    }
    @Test func aHiddenCountLeavesTheStripButStaysInTheTooltip() {
        #expect(MenuBarSummary.segments(waiting: 2, unread: 3, showsWaiting: false).map(\.count) == [3])
        #expect(MenuBarSummary.segments(waiting: 2, unread: 3, showsUnread: false).map(\.count) == [2])
        #expect(MenuBarSummary.segments(
            waiting: 2, unread: 3, showsWaiting: false, showsUnread: false
        ).isEmpty)
        #expect(MenuBarSummary.tooltip(waiting: 2, unread: 3).contains("2"))
    }
}
