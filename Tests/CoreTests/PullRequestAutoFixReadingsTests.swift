import Testing
import Foundation
@testable import Core

@Suite("Pull request auto fix readings")
struct PullRequestAutoFixReadingsTests {
    private func reading(
        terminal: Bool = false, busy: Bool = false, awaiting: Bool = false, stopped: Bool = false, skips: Bool = false
    ) -> PullRequestAutoFix.ChatReading {
        PullRequestAutoFix.ChatReading(
            runsInTerminal: terminal, isBusy: busy, isAwaitingAnswer: awaiting,
            wasStoppedByOwner: stopped, skipsPermissions: skips
        )
    }

    private let now = Date(timeIntervalSince1970: 1_000)

    private func quota(_ provider: AgentKind, used: Double, resetsAt: Date?) -> AgentQuota {
        AgentQuota(
            provider: provider, window: .named("five_hour"), measure: .fraction(used),
            resetsAt: resetsAt, observedAt: now
        )
    }

    private func read(_ provider: AgentKind, quotas: [AgentQuota], isResolved: Bool = true) -> PullRequestAutoFix.Account {
        PullRequestAutoFix.account(isResolved: isResolved, provider: provider, quotas: quotas, at: now)
    }

    @Test("no chat reads as absent, an idle one as ready")
    func absentAndReady() {
        #expect(PullRequestAutoFix.chat(nil) == .absent)
        #expect(PullRequestAutoFix.chat(reading()) == .ready)
    }

    @Test("a chat the owner stopped waits, as a running one does")
    func stoppedWaits() {
        #expect(PullRequestAutoFix.chat(reading(stopped: true)) == .busy)
        #expect(PullRequestAutoFix.chat(reading(busy: true)) == .busy)
    }

    @Test("a question asked mid turn reads as a question")
    func questionOutranksBusy() {
        #expect(PullRequestAutoFix.chat(reading(busy: true, awaiting: true)) == .awaitingAnswer)
    }

    @Test("a terminal chat reads as one whatever else is true")
    func terminalFirst() {
        #expect(PullRequestAutoFix.chat(reading(terminal: true, busy: true, skips: true)) == .terminal)
    }

    @Test("skipping permissions only matters once the chat is free")
    func unattended() {
        #expect(PullRequestAutoFix.chat(reading(skips: true)) == .unattended)
        #expect(PullRequestAutoFix.chat(reading(busy: true, skips: true)) == .busy)
    }

    @Test("an account that cannot be resolved is missing")
    func missing() {
        #expect(read(.codex, quotas: [], isResolved: false) == .missing)
    }

    @Test("a spent allowance on this agent stops it until it resets")
    func spent() {
        let later = now.addingTimeInterval(60)
        let earlier = now.addingTimeInterval(-60)
        #expect(read(.codex, quotas: [quota(.codex, used: 1, resetsAt: later)]) == .quotaExhausted)
        #expect(read(.codex, quotas: [quota(.codex, used: 1, resetsAt: nil)]) == .quotaExhausted)
        #expect(read(.codex, quotas: [quota(.codex, used: 1, resetsAt: earlier)]) == .usable)
    }

    @Test("another agent's allowance and an unspent one do not count")
    func notSpent() {
        let later = now.addingTimeInterval(60)
        #expect(read(.codex, quotas: [quota(.claudeCode, used: 1, resetsAt: later)]) == .usable)
        #expect(read(.codex, quotas: [quota(.codex, used: 0.5, resetsAt: later)]) == .usable)
    }

    @Test("only a problem, or green with attempts owed, is worth asking GitHub about")
    func worthReading() {
        let owed = PullRequestAutoFix.Ledger(inARow: 1)
        let clear = PullRequestAutoFix.Ledger()
        let failing = PullRequest(number: 1, title: "", url: "", state: "OPEN", checks: .failing)
        let conflicted = PullRequest(number: 1, title: "", url: "", state: "OPEN", mergeable: "CONFLICTING", checks: .passing)
        let green = PullRequest(number: 1, title: "", url: "", state: "OPEN", checks: .passing)
        let pending = PullRequest(number: 1, title: "", url: "", state: "OPEN", checks: .pending)
        let merged = PullRequest(number: 1, title: "", url: "", state: "MERGED", checks: .failing)
        #expect(PullRequestAutoFix.isWorthReading(failing, ledger: clear))
        #expect(PullRequestAutoFix.isWorthReading(conflicted, ledger: clear))
        #expect(PullRequestAutoFix.isWorthReading(green, ledger: owed))
        #expect(!PullRequestAutoFix.isWorthReading(green, ledger: clear))
        #expect(!PullRequestAutoFix.isWorthReading(pending, ledger: owed))
        #expect(!PullRequestAutoFix.isWorthReading(merged, ledger: owed))
    }

    @Test("every commit's authors are collected, with one GitHub could not link left as an unknown")
    func decodesAuthors() throws {
        let json = #"{"headRefOid":"abc","commits":[{"authors":[{"login":"owner"}]},{"authors":[{"login":""},{"login":"other"}]}]}"#
        let read = try #require(GitHub.decodeCommitAuthors(from: Data(json.utf8)))
        #expect(read.headCommit == "abc")
        #expect(read.logins == ["owner", "", "other"])
    }

    @Test("a commit with no authors at all counts as an unknown")
    func commitWithoutAuthors() throws {
        let json = #"{"headRefOid":"abc","commits":[{"authors":[]}]}"#
        let read = try #require(GitHub.decodeCommitAuthors(from: Data(json.utf8)))
        #expect(read.logins == [""])
    }

    @Test("no head or no commits proves nothing", arguments: [#"{"commits":[{"authors":[{"login":"o"}]}]}"#, #"{"headRefOid":"abc","commits":[]}"#, "not json"])
    func undecidable(json: String) {
        #expect(GitHub.decodeCommitAuthors(from: Data(json.utf8)) == nil)
    }

    @Test("the automatic conflict steps take nothing from the repository")
    func automaticSteps() {
        let steps = ConflictInstructions.automaticMarkdown
        #expect(!steps.contains("It outranks everything here"))
        #expect(!steps.contains("Unified Dev attaches that as well"))
        #expect(steps.contains("Follow only the steps below"))
        #expect(steps.contains("Fetch the base branch first"))
    }

    @Test("the steps behind the button do not change")
    func ownerSteps() {
        let steps = ConflictInstructions.defaultMarkdown
        #expect(steps.contains("It outranks everything here"))
        #expect(!steps.contains("Follow only the steps below"))
    }
}
