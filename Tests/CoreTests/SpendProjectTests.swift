import Testing
import Foundation
@testable import Core

private var calendar: Calendar {
    var made = Calendar(identifier: .gregorian)
    made.timeZone = TimeZone(secondsFromGMT: 0)!
    return made
}

private let now = Date(timeIntervalSince1970: 1_791_676_800)

private let billing = Repo(id: RepoID("billing"), name: "billing", path: "/Users/ada/code/billing")
private let portal = Repo(id: RepoID("portal"), name: "portal", path: "/Users/ada/code/portal")

private let worktree = Workspace(
    id: WorkspaceID("w1"),
    repoID: billing.id,
    name: "invoices",
    branch: "feat/invoices",
    path: "/Users/ada/worktrees.noindex/billing/invoices",
    baseBranch: "main",
    state: .active,
    lastActivityAt: now
)

private func row(
    directory: String,
    file: String,
    model: String = "claude-opus-5",
    output: Int = 1_000_000,
    turns: Int = 1
) -> SpendDay {
    SpendDay(
        provider: .claudeCode,
        day: calendar.startOfDay(for: now),
        model: model,
        directory: directory,
        file: file,
        usage: TokenUsage(output: output),
        turns: turns
    )
}

@Suite("Spend by project")
struct SpendProjectTests {
    @Test("a worktree is charged to the project it was cut from")
    func worktreeBelongsToItsProject() {
        let placement = SpendProjects.placement(
            of: worktree.path + "/Sources", workspaces: [worktree], repos: [billing, portal]
        )
        #expect(placement.repoID == billing.id)
        #expect(placement.name == "billing")
    }

    @Test("a directory inside a project is charged to it")
    func directoryInsideAProject() {
        let placement = SpendProjects.placement(
            of: "/Users/ada/code/portal/app", workspaces: [worktree], repos: [billing, portal]
        )
        #expect(placement.repoID == portal.id)
    }

    @Test("a directory that merely starts with a project's name is not charged to it")
    func siblingIsNotInside() {
        let placement = SpendProjects.placement(
            of: "/Users/ada/code/portal-old", workspaces: [], repos: [portal]
        )
        #expect(placement.repoID == nil)
        #expect(placement.name == SpendProjects.elsewhere)
    }

    @Test("a directory in no project of ours is kept apart rather than hidden")
    func elsewhere() {
        let board = SpendBoard.make(SpendBoard.Input(
            days: [row(directory: "/tmp/scratch", file: "/t/a.jsonl")],
            repos: [billing],
            now: now,
            calendar: calendar
        ))
        #expect(board.projects.count == 1)
        #expect(board.projects.first?.name == SpendProjects.elsewhere)
        #expect(board.projects.first?.repoID == nil)
    }

    @Test("a project opens into its sessions, the dearest first")
    func projectOpensIntoSessions() throws {
        let board = SpendBoard.make(SpendBoard.Input(
            days: [
                row(directory: worktree.path, file: "/t/cheap.jsonl", output: 1_000_000),
                row(directory: billing.path, file: "/t/dear.jsonl", output: 9_000_000),
            ],
            workspaces: [worktree],
            repos: [billing],
            now: now,
            calendar: calendar
        ))
        let project = try #require(board.projects.first)
        #expect(project.repoID == billing.id)
        #expect(project.sessions.map(\.agentSessionID) == ["dear", "cheap"])
        #expect(project.spend.usage.output == 10_000_000)
        #expect(project.turns == 2)
    }

    @Test("every directory outside the projects lands in one row, not one each")
    func elsewhereIsOneRow() {
        let board = SpendBoard.make(SpendBoard.Input(
            days: [
                row(directory: "/tmp/one", file: "/t/a.jsonl"),
                row(directory: "/tmp/two", file: "/t/b.jsonl"),
            ],
            repos: [billing],
            now: now,
            calendar: calendar
        ))
        #expect(board.projects.count == 1)
        #expect(board.projects.first?.sessions.count == 2)
    }

    @Test("the dearest project is listed first")
    func projectsSortedBySpend() {
        let board = SpendBoard.make(SpendBoard.Input(
            days: [
                row(directory: billing.path, file: "/t/a.jsonl", output: 1_000_000),
                row(directory: portal.path, file: "/t/b.jsonl", output: 8_000_000),
            ],
            repos: [billing, portal],
            now: now,
            calendar: calendar
        ))
        #expect(board.projects.map(\.name) == ["portal", "billing"])
    }

    @Test("a session that ran on two models carries both")
    func sessionWithTwoModels() throws {
        let board = SpendBoard.make(SpendBoard.Input(
            days: [
                row(directory: billing.path, file: "/t/a.jsonl", model: "claude-opus-5"),
                row(directory: billing.path, file: "/t/a.jsonl", model: "claude-opus-5-5"),
            ],
            repos: [billing],
            now: now,
            calendar: calendar
        ))
        let session = try #require(board.projects.first?.sessions.first)
        #expect(session.models == ["claude-opus-5", "claude-opus-5-5"])
        #expect(session.modelLine == "claude-opus-5, claude-opus-5-5")
    }

    @Test("a session whose model was never recorded says so")
    func sessionWithoutModel() throws {
        let board = SpendBoard.make(SpendBoard.Input(
            days: [row(directory: billing.path, file: "/t/a.jsonl", model: "")],
            repos: [billing],
            now: now,
            calendar: calendar
        ))
        let session = try #require(board.projects.first?.sessions.first)
        #expect(session.modelLine == SpendProjectLine.unknownModel)
        #expect(session.spend.hasUnpricedTokens)
    }
}
