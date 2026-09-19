import Foundation
import Testing
@testable import Core

@Suite("Suggested work in the store", .tags(.persistence), .scratchDirectory)
struct WorkSuggestionStoreTests {
    private struct Fixture {
        let store: Store
        let repo: Repo
        let workspace: Workspace
        let chat: Session

        func suggestion(
            _ title: String = "Keep the last row",
            target: WorkSuggestion.Target = .sameProject,
            in chat: Session? = nil
        ) -> WorkSuggestion {
            WorkSuggestion(
                workspaceID: workspace.id,
                sessionID: (chat ?? self.chat).id,
                title: title,
                why: "The parser drops the last row of every file.",
                prompt: "Make the parser keep the last row, with a test that fails without the fix.",
                target: target
            )
        }
    }

    private func fixture(_ label: String) async throws -> Fixture {
        let store = try makeTestStore(label)
        let repo = try await store.upsert(Repo(name: "lantern", path: "/tmp/lantern", defaultBranch: "main"))
        let workspace = try await store.upsert(Workspace(
            repoID: repo.id, name: "Importer", branch: "importer",
            path: "/tmp/lantern-importer", baseBranch: "main"
        ))
        let chat = try await store.upsert(Session(workspaceID: workspace.id, title: "Import"))
        return Fixture(store: store, repo: repo, workspace: workspace, chat: chat)
    }

    @Test("a suggestion is kept whole, waiting for the owner, whatever it points at", arguments: [
        WorkSuggestion.Target.sameProject,
        .project(RepoID("r-almanac")),
        .folder("/Users/kid/tidewater"),
        .remote("octo/parsekit"),
    ])
    func roundTrip(target: WorkSuggestion.Target) async throws {
        let f = try await fixture("suggestion-round-trip")
        let written = f.suggestion(target: target)

        let admission = try await f.store.addWorkSuggestion(written)
        let stored = try #require(admission.suggestion)
        let read = try #require(try await f.store.workSuggestion(id: written.id))

        #expect(read == stored)
        #expect(read.target == target)
        #expect(read.state == .pending)
        #expect(read.title == written.title)
        #expect(read.why == written.why)
        #expect(read.prompt == written.prompt)
        #expect(read.workspaceID == f.workspace.id)
        #expect(read.sessionID == f.chat.id)
        #expect(read.failure == nil)
        #expect(read.decidedAt == nil)
    }

    @Test("a sixth undecided suggestion in one workspace is refused, and deciding one frees a place")
    func fiveAtOnce() async throws {
        let f = try await fixture("suggestion-limit")
        var ids: [WorkSuggestionID] = []
        for index in 1...WorkSuggestion.undecidedLimit {
            let admission = try await f.store.addWorkSuggestion(f.suggestion("Work \(index)"))
            ids.append(try #require(admission.suggestion).id)
        }

        let sixth = try await f.store.addWorkSuggestion(f.suggestion("Work 6"))
        let held = try await f.store.workSuggestions(sessionID: f.chat.id)
        try await f.store.dismissWorkSuggestion(id: ids[0])
        let retried = try await f.store.addWorkSuggestion(f.suggestion("Work 6"))

        #expect(sixth == .full(undecided: WorkSuggestion.undecidedLimit))
        #expect(held.count == WorkSuggestion.undecidedLimit)
        #expect(retried.suggestion != nil)
    }

    @Test("the five are counted across the workspace's chats, and an archived chat's stop counting")
    func countedPerWorkspace() async throws {
        let f = try await fixture("suggestion-limit-chats")
        let review = try await f.store.upsert(Session(workspaceID: f.workspace.id, title: "Review"))
        for index in 1...3 { _ = try await f.store.addWorkSuggestion(f.suggestion("Import \(index)")) }
        for index in 1...2 { _ = try await f.store.addWorkSuggestion(f.suggestion("Review \(index)", in: review)) }

        let refused = try await f.store.addWorkSuggestion(f.suggestion("One more"))
        _ = try await f.store.update(sessionID: review.id) { $0.archivedAt = Date() }
        let accepted = try await f.store.addWorkSuggestion(f.suggestion("One more"))
        let counts = try await f.store.undecidedWorkSuggestionCounts()

        #expect(refused == .full(undecided: 5))
        #expect(accepted.suggestion != nil)
        #expect(counts == [f.workspace.id: 4])
    }

    @Test("an Ask chat, which is in no workspace, holds its own five")
    func askChatsCountAlone() async throws {
        let f = try await fixture("suggestion-ask")
        let ask = try await f.store.upsert(Session(workspaceID: nil, title: "Ask"))
        func fromAsk(_ title: String) -> WorkSuggestion {
            WorkSuggestion(
                workspaceID: nil, sessionID: ask.id, title: title, why: "Because.",
                prompt: "Do it.", target: .project(f.repo.id)
            )
        }
        for index in 1...WorkSuggestion.undecidedLimit {
            _ = try await f.store.addWorkSuggestion(fromAsk("Ask \(index)"))
        }

        let sixth = try await f.store.addWorkSuggestion(fromAsk("Ask 6"))
        let workspaceOne = try await f.store.addWorkSuggestion(f.suggestion())
        let counts = try await f.store.undecidedWorkSuggestionCounts()

        #expect(sixth == .full(undecided: WorkSuggestion.undecidedLimit))
        #expect(workspaceOne.suggestion != nil)
        #expect(counts == [f.workspace.id: 1])
    }

    @Test("a suggestion is claimed once, and the second claim is told what the first did")
    func claimedOnce() async throws {
        let f = try await fixture("suggestion-claim")
        let suggestion = try #require(try await f.store.addWorkSuggestion(f.suggestion()).suggestion)

        let first = try await f.store.claimWorkSuggestion(id: suggestion.id)
        let second = try await f.store.claimWorkSuggestion(id: suggestion.id)
        let missing = try await f.store.claimWorkSuggestion(id: WorkSuggestionID("nowhere"))

        guard case .claimed(let claimed) = first else { Issue.record("first claim: \(first)"); return }
        guard case .taken(let taken) = second else { Issue.record("second claim: \(second)"); return }
        #expect(claimed.state == .starting)
        #expect(taken.state == .starting)
        #expect(missing == .missing)
    }

    @Test("a start is recorded with what it became, and a failed one waits again with its reason")
    func settlesAndReleases() async throws {
        let f = try await fixture("suggestion-settle")
        let one = try #require(try await f.store.addWorkSuggestion(f.suggestion("One")).suggestion)
        let two = try #require(try await f.store.addWorkSuggestion(f.suggestion("Two")).suggestion)
        _ = try await f.store.claimWorkSuggestion(id: one.id)
        _ = try await f.store.claimWorkSuggestion(id: two.id)

        let started = try await f.store.settleWorkSuggestion(
            id: one.id, as: .startedWorkspace(WorkspaceID("w-born"), name: "Keep the last row")
        )
        try await f.store.releaseWorkSuggestion(id: two.id, failure: "Try again once one of them is archived.")
        let released = try await f.store.workSuggestion(id: two.id)
        let again = try await f.store.claimWorkSuggestion(id: one.id)

        #expect(started?.state == .startedWorkspace(WorkspaceID("w-born"), name: "Keep the last row"))
        #expect(started?.decidedAt != nil)
        #expect(released?.state == .pending)
        #expect(released?.failure == "Try again once one of them is archived.")
        guard case .taken = again else { Issue.record("a started suggestion was claimed again: \(again)"); return }
    }

    @Test("only the chat that made a suggestion may withdraw it, and only while it waits")
    func withdrawing() async throws {
        let f = try await fixture("suggestion-withdraw")
        let other = try await f.store.upsert(Session(workspaceID: f.workspace.id, title: "Review"))
        let mine = try #require(try await f.store.addWorkSuggestion(f.suggestion("Mine")).suggestion)
        let dismissed = try #require(try await f.store.addWorkSuggestion(f.suggestion("Dismissed")).suggestion)
        try await f.store.dismissWorkSuggestion(id: dismissed.id)

        let byAnother = try await f.store.withdrawWorkSuggestion(id: mine.id, by: other.id)
        let decided = try await f.store.withdrawWorkSuggestion(id: dismissed.id, by: f.chat.id)
        let byItsChat = try await f.store.withdrawWorkSuggestion(id: mine.id, by: f.chat.id)
        let missing = try await f.store.withdrawWorkSuggestion(id: WorkSuggestionID("nowhere"), by: f.chat.id)

        #expect(byAnother == .notYours)
        guard case .alreadyDecided(let found) = decided else { Issue.record("\(decided)"); return }
        #expect(found.state == .dismissed)
        guard case .withdrawn(let withdrawn) = byItsChat else { Issue.record("\(byItsChat)"); return }
        #expect(withdrawn.state == .withdrawn)
        #expect(withdrawn.decidedAt != nil)
        #expect(missing == .missing)
    }

    @Test("a claim left behind by a launch that died is released at the next launch")
    func releasesAbandonedClaims() async throws {
        let f = try await fixture("suggestion-abandoned")
        let suggestion = try #require(try await f.store.addWorkSuggestion(f.suggestion()).suggestion)
        _ = try await f.store.claimWorkSuggestion(id: suggestion.id)

        let released = try await f.store.releaseWorkSuggestionClaims()
        let read = try await f.store.workSuggestion(id: suggestion.id)

        #expect(released == 1)
        #expect(read?.state == .pending)
    }

    @Test("a workspace deleted takes its chats' suggestions with it")
    func cascades() async throws {
        let f = try await fixture("suggestion-cascade")
        let suggestion = try #require(try await f.store.addWorkSuggestion(f.suggestion()).suggestion)

        try await f.store.deleteWorkspace(id: f.workspace.id)
        let read = try await f.store.workSuggestion(id: suggestion.id)

        #expect(read == nil)
    }

    @Test("a suggestion written tells whoever is watching suggested work")
    func publishesItsDomain() async throws {
        let f = try await fixture("suggestion-feed")
        let feed = f.store.changes(of: [.workSuggestions])
        let seen = Task { () -> Set<StoreDomain>? in
            var iterator = feed.makeAsyncIterator()
            return await iterator.next()
        }
        await waitUntil("the feed has subscribed") { f.store.changeHub.subscriberCount > 0 }

        _ = try await f.store.addWorkSuggestion(f.suggestion())

        #expect(await seen.value == [.workSuggestions])
    }
}
